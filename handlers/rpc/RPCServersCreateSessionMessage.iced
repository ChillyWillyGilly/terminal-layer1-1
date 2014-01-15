persistency = require '../../lib/persistency.iced'

messageBus = require '../../lib/messagebus.iced'

REPLY_MESSAGE = 'RPCServersCreateSessionResultMessage'

module.exports = (data, state) ->
	# get the connection npid
	await persistency.getConnField state, 'npid', defer err, npid

	# return an error if not authenticated
	if not npid
		state.reply REPLY_MESSAGE,
			result: 1
			sessionid: ''

		return

	await persistency.client.incr 'npm:session_id', defer err, sessionid

	for field of data.info.data
		await persistency.setSessionField sessionid, field.key, field.value, defer err

	await persistency.setSessionField sessionid, 'address', data.info.address + ':' + data.info.port, defer err
	await persistency.setSessionField sessionid, 'players', data.info.players + '/' + data.info.maxplayers, defer err

	await persistency.setSessionField sessionid, 'sid', sessionid, defer err
	await persistency.setSessionField sessionid, 'npid', npid, defer err

	await persistency.setConnField state, 'sessionid', sessionid, defer err

	state.reply REPLY_MESSAGE
		result: 0
		sessionid: [ sessionid >> 32 , sessionid & 0xFFFFFFFF ]