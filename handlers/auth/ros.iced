# request module
request = require 'request'

RosCrypt = require './roscrypt'

gameSettings = 
    gta5:
        secret: 'C4pWJwWIKGUxcHd69eGl2AOwH2zrmzZAoQeHfQFcMelybd32QFw9s10px6k0o75XZeB5YsI9Q9TdeuRgdbvKsxc='
        newSecurity: true

    mp3:
        secret: 'C/9UmxenWfiN5LxXok/KWT4dX9MA+umtsmsIO3/RvegqJKPWhKne4VgNt+oq5de8Le+JLBsATQXtiKTVMk6CO24='

for k, v of gameSettings
    v.rosCrypt = RosCrypt v.secret
    v.name = k

querystring = require 'querystring'

{parseString} = require 'xml2js'

socks_agent = require 'socks5-http-client/lib/Agent'

url = require 'url'

crypto = require 'crypto'

addSecurity = (game, options, sessionKey, sessionTicket) ->
    # define headers
    options.headers['ros-SecurityFlags'] = '239' # nothing else is allowed in prod
    options.headers['ros-Challenge'] = new Buffer(8).toString 'base64' # to make the HMAC more random?
    options.headers['ros-SessionTicket'] = sessionTicket

    # set HMAC
    nullBuffer = new Buffer(1)
    nullBuffer.writeUInt8 0, 0

    baseKey = game.rosCrypt.getBaseKey false

    key = new Buffer(16)

    for i in [0..15]
        key.writeUInt8 (baseKey.readUInt8(i) ^ sessionKey.readUInt8(i)), i

    hmac = crypto.createHmac 'sha1', key

    # helper to append null buffer
    updateString = (str) ->
        hmac.update str
        hmac.update nullBuffer

    # add the request method
    updateString options.method

    # add the request URI
    parts = url.parse options.url

    updateString parts.path

    # security headers
    updateString options.headers['ros-SecurityFlags']
    updateString options.headers['ros-SessionTicket']
    updateString options.headers['ros-Challenge']

    # platform hash key
    hmac.update game.rosCrypt.getBaseKey true

    # set hmac
    options.headers['ros-HeadersHmac'] = hmac.digest().toString 'base64'

requestRos = (game, service, kv, secOptions, cb) ->
    ua = game.rosCrypt.encryptUA "e=1,t=#{ game.name },p=pcros,v=11"
    
    sessionKey = null
    sessionTicket = null

    sessionKey = secOptions.sessionKey if secOptions
    sessionTicket = secOptions.sessionTicket if secOptions

    sessionKey = new Buffer(sessionKey, 'base64') if sessionKey

    options = 
        url: "http://prod.ros.rockstargames.com/#{ game.name }/11/gameservices/#{ service }"
        headers: 
            'User-Agent': 'ros ' + ua
            'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8'
            'Accept': 'text/html'
        method: 'POST'
        body: game.rosCrypt.encrypt new Buffer(querystring.stringify kv), sessionKey
        encoding: null
        strictSSL: false
        agentClass: socks_agent
        agentOptions:
            socksPort: 9050

    if game.newSecurity and sessionKey
        addSecurity game, options, sessionKey, sessionTicket

    await request options, defer err, response, body

    if err
        cb err
    else
        try
            if response.statusCode == 200
                decrypted = game.rosCrypt.decrypt(body, false, sessionKey).toString 'utf8'

                cb null, decrypted
            else
                console.log body.toString 'utf8'

                cb "error from ros request"
        catch e
            console.log response.statusCode
            console.log response.headers

            cb e

module.exports = (token, state, reply) ->
    tokenParts = token.split('&&')
    ticket = tokenParts[0]
    id = tokenParts[1]
    game = gameSettings[tokenParts[2] or 'mp3'] or gameSettings['mp3']
    sessionKey = tokenParts[3]
    sessionTicket = tokenParts[4]

    await requestRos game, 'Friends.asmx/InviteByRockstarId',
        ticket: ticket
        rockstarId: id
    , {sessionKey: sessionKey, sessionTicket: sessionTicket }, defer err, res

    if err
        console.log err

        reply 2
    else
        await parseString res, defer err, result

        result = result.Response if result

        if err
            console.log err

            reply 2
        else
            if result.Error and result.Error[0].$.Code and result.Error[0].$.Code == 'InvalidArgument' and result.Error[0].$.CodeEx == 'InviteeRockstarId'
                npid = [ 0x1400001, parseInt id ]

                reply 0, npid, [ 'ros', id ]
            else
                reply 1
