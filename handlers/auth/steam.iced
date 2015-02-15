nano = require 'nanomsg'

appids = [ 12210, 204100, 271590, 218 ]

sockets = {}

cbs = {}
reqId = 1

for appid in appids
	sockets[appid] = nano.socket 'pair'
	sockets[appid].connect 'ipc:///tmp/terminal-steam-' + appid + '.pipe'

	sockets[appid].on 'message', (buf) ->
		req 		= buf.readUInt32LE 0
		steamIDLow 	= buf.readUInt32LE 4
		steamIDHigh = buf.readUInt32LE 8
		errorCode 	= buf.readUInt32LE 12

		lowStr		= steamIDLow.toString(16)
		pad			= '00000000'

		lowStr 		= pad.substring(0, 8 - lowStr.length) + lowStr

		steamID 	= steamIDHigh.toString(16) + lowStr

		console.log 'get steam ' + req

		if cbs[req]
			cb = cbs[req]

			if errorCode != 0
				console.log 'auth for req ' + req + ' failed with error code ' + errorCode

				cb 1
			else
				cb 0, [ steamIDHigh, steamIDLow ], [ 'steam', steamID ]

			delete cbs[req]

module.exports = (token, state, reply) ->
	parts = token.split '&'
	appid = parts[0]
	token = parts[1]

	buffer = new Buffer(token, 'base64')

	outBuffer = new Buffer(buffer.length + 4)
	outBuffer.writeUInt32LE reqId, 0
	buffer.copy outBuffer, 4

	cbs[reqId] = reply

	id = reqId

	setTimeout () ->
		if cbs[id]
			cbs[id] 2
			delete cbs[id]
	, 15000

	console.log 'send steam ' + reqId

	reqId++

	if sockets[appid]
		sockets[appid].send outBuffer