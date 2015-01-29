# request module
request = require 'request'

rosCrypt = require './roscrypt'
rosCrypt.setSecret 'C/9UmxenWfiN5LxXok/KWT4dX9MA+umtsmsIO3/RvegqJKPWhKne4VgNt+oq5de8Le+JLBsATQXtiKTVMk6CO24='

querystring = require 'querystring'

{parseString} = require 'xml2js'

requestRos = (service, kv, cb) ->
    ua = rosCrypt.encryptUA 'e=1,t=mp3,p=pcros,v=11'

    await request
        url: 'https://prod.ros.rockstargames.com/mp3/11/gameservices/' + service
        headers:
            'User-Agent': 'ros ' + ua
            'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8'
            'Accept': 'text/html'
        method: 'POST'
        body: rosCrypt.encrypt new Buffer(querystring.stringify kv)
        encoding: null
        strictSSL: false
    , defer err, response, body

    if err
        cb err
    else
        try
            cb null, rosCrypt.decrypt(body).toString 'utf8'
        catch e
            cb e

module.exports = (token, state, reply) ->
    tokenParts = token.split('&&')
    ticket = tokenParts[0]
    id = tokenParts[1]

    await requestRos 'Friends.asmx/InviteByRockstarId',
        ticket: ticket
        rockstarId: id
    , defer err, res

    if err
        reply 2
    else
        await parseString res, defer err, result

        result = result.Response

        if err
            reply 2
        else
            if result.Error and result.Error[0].$.Code and result.Error[0].$.Code == 'InvalidArgument' and result.Error[0].$.CodeEx == 'InviteeRockstarId'
                npid = [ 0x1400001, parseInt id ]

                reply 0, npid, [ 'ros', id ]
            else
                reply 1
