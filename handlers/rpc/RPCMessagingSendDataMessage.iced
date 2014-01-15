persistency = require '../../lib/persistency.iced'

messageBus = require '../../lib/messagebus.iced'

int64 = require 'int64-native'

REPLY_MESSAGE = 'RPCMessagingSendDataMessage'

module.exports = (data, state) ->
	# get the connection npid
	await persistency.getConnField state, 'npid', defer err, npid

	# return if not authenticated
	return if not npid

	npid64 = new int64(parseInt(npid.substring(0, 8), 16), parseInt(npid.substring(8), 16))

	# get target id
	targetid64 = new int64(data.npid[0], data.npid[1])
	targetid = targetid64.toString()

	# get the target npid's connections
	await persistency.client.lrange persistency.getUserKey(data.npid, 'conns'), 0, -1, defer err, connections

	# if no connection exists, return the appropriate error
	if not connections or not connections.length
		errBuffer = new Buffer(8)
		errBuffer.writeUInt32LE 0xDEADDEAD, 0
		errBuffer.writeUInt32LE 4, 4

		state.reply REPLY_MESSAGE, 
			npid: data.npid
			data: errBuffer

		return

	# send the message to all open connections
	for connID in connections
		targetState = 
			id: { token: connID, id: 0 }
			token: connID

		# get the reply queue used for this transport
		await persistency.getConnField targetState, 'replyQueue', defer err, replyTo

		targetState.replyTo = replyTo

		# send a fake reply
		replyFunc = messageBus.getReplyFunction targetState

		replyFunc REPLY_MESSAGE,
			npid: [ npid64.high32(), npid64.low32() ]
			data: data.data
			_buffer: 'data'
