# request module
request = require 'request'

RosCrypt = require './roscrypt'

gameSettings = 
    gta5:
        secret: 'C4pWJwWIKGUxcHd69eGl2AOwH2zrmzZAoQeHfQFcMelybd32QFw9s10px6k0o75XZeB5YsI9Q9TdeuRgdbvKsxc='

    mp3:
        secret: 'C/9UmxenWfiN5LxXok/KWT4dX9MA+umtsmsIO3/RvegqJKPWhKne4VgNt+oq5de8Le+JLBsATQXtiKTVMk6CO24='

for k, v of gameSettings
    v.rosCrypt = RosCrypt v.secret
    v.name = k

querystring = require 'querystring'

{parseString} = require 'xml2js'

requestRos = (game, service, kv, cb) ->
    ua = rosCrypt.encryptUA "e=1,t=#{ game.name },p=pcros,v=11"

    await request
        url: "https://prod.ros.rockstargames.com/#{ game.name }/11/gameservices/#{ service }"
        headers:
            'User-Agent': 'ros ' + ua
            'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8'
            'Accept': 'text/html'
        method: 'POST'
        body: game.rosCrypt.encrypt new Buffer(querystring.stringify kv)
        encoding: null
        strictSSL: false
    , defer err, response, body

    if err
        cb err
    else
        try
            cb null, game.rosCrypt.decrypt(body).toString 'utf8'
        catch e
            cb e

module.exports = (token, state, reply) ->
    tokenParts = token.split('&&')
    ticket = tokenParts[0]
    id = tokenParts[1]
    game = gameSettings[tokenParts[2] or 'mp3'] or gameSettings['mp3']

    await requestRos game, 'Friends.asmx/InviteByRockstarId',
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
