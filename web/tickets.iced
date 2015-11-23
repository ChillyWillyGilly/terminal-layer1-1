persistency = require '../lib/persistency.iced'

int64 = require 'int64-native'

bodyParser = require 'body-parser'

readTicket = (ticket) ->
    data =
        version: ticket.readUInt32LE 0

    if data.version == 1
        data.clientID = new int64(ticket.readUInt32LE(8), ticket.readUInt32LE 4)
        data.serverID = new int64(ticket.readUInt32LE(16), ticket.readUInt32LE 12).toString()

        data.time = ticket.readUInt32LE 20

    data

module.exports.initialize = (app) ->
    app.post '/ticket/validate', bodyParser.json(), (req, res) ->
        return res.sendStatus 400 if not req.body

        try
            # response object
            response = {}

            # validate presence of input fields
            requiredFields = ['npid', 'clientIP', 'ticket']

            for f in requiredFields
                throw new Error("Missing field: #{ f }") if not req.body[f]

            # parse each field as appropriate
            npidBit = new int64(req.body.npid)
            ticket = new Buffer(req.body.ticket, 'base64')
            ip = req.body.clientIP

            # read the ticket
            ticket = readTicket ticket

            throw new Error('Invalid ticket version') unless ticket.version == 1

            # validate the client identifier
            throw new Error('Mismatching client identifier') unless (npidBit.high32() == ticket.clientID.high32() and npidBit.low32() == ticket.clientID.low32())

            # get the target npid's connections
            await persistency.client.lrange persistency.getUserKey(npidBit.toString(), 'conns'), 0, -1, defer err, connections

            # if no connection exists, return the appropriate error
            if not connections or not connections.length
                throw new Error('Client is not connected')
            else
                # check all open connections
                for connID in connections
                    targetState =
                        id: { token: connID, id: 0 }
                        token: connID

                    await persistency.getConnField targetState, 'remoteID', defer err, remoteID

                    if remoteID == ip or ip.indexOf('192.168') == 0 or ip.indexOf('172.1') == 0 or ip.indexOf('172.2') == 0 or ip.indexOf('10.') == 0 or ip.indexOf('127.') == 0
                        await persistency.getConnField targetState, 'identifiers', defer err, identifierString

                        return res.status(200).json({ valid: true, identifiers: identifierString })

            throw new Error('IP address does not match')

        catch e
            res.status(200).json({ error: e.message, valid: false })
