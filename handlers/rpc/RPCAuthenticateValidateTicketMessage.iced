persistency = require '../../lib/persistency.iced'

messageBus = require '../../lib/messagebus.iced'

int64 = require 'int64-native'

REPLY_MESSAGE = 'RPCAuthenticateValidateTicketResultMessage'

readTicket = (ticket) ->
    data =
        version: ticket.readUInt32LE 0

    if data.version == 1
        data.clientID = new int64(ticket.readUInt32LE(8), ticket.readUInt32LE 4)
        data.serverID = new int64(ticket.readUInt32LE(16), ticket.readUInt32LE 12).toString()

        data.time = ticket.readUInt32LE 20

    data

module.exports = (data, state) ->
    ipNum = data.clientIP

    ip = ((ipNum >> 24) & 0xFF) + '.' + ((ipNum >> 16) & 0xFF) + '.' + ((ipNum >> 8) & 0xFF) + '.' + (ipNum & 0xFF)

    ticket = readTicket new Buffer(data.ticket)

    valid = false

    identifierString = 'null'

    if ticket.version == 1
        # get the connection npid
        await persistency.getConnField state, 'npid', defer err, npid

        if npid == ticket.serverID
            if data.npid[0] == ticket.clientID.high32() and data.npid[1] == ticket.clientID.low32()
                # get the target npid's connections
                await persistency.client.lrange persistency.getUserKey(data.npid, 'conns'), 0, -1, defer err, connections

                # if no connection exists, return the appropriate error
                if not connections or not connections.length
                    valid = false
                else
                    # check all open connections
                    for connID in connections
                        targetState =
                            id: { token: connID, id: 0 }
                            token: connID

                        await persistency.getConnField targetState, 'remoteID', defer err, remoteID

                        if remoteID == ip or ip.indexOf('192.168') == 0 or ip.indexOf('172.1') == 0 or ip.indexOf('172.2') == 0 or ip.indexOf('10.') == 0
                            await persistency.getConnField targetState, 'identifiers', defer err, identifierString

                            valid = true


    result = 0 if valid
    result = 1 if not valid

    state.reply REPLY_MESSAGE,
        result: result
        groupID: 0
        npid: data.npid
        identifiers: identifierString
