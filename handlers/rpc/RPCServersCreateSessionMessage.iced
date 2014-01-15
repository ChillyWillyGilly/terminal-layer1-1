persistency = require '../../lib/persistency.iced'

messageBus = require '../../lib/messagebus.iced'

service = require '../../services/sessions.iced'

int64 = require 'int64-native'

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

	# remove any old sessions by this connection
	await persistency.getConnField state, 'sessionid', defer err, oldsid

	if oldsid
		await service.deleteSession oldsid, state.token, defer err

	# get a new session id
	await persistency.client.incr 'npm:session_id', defer err, sessionid

	# set extended fields
	for field in data.info.data
		await persistency.setSessionField sessionid, '_' + field.key, field.value, defer err

		await persistency.client.sadd "npm:sdata:_#{ field.key }:#{ field.value }", sessionid, defer err

	await persistency.client.sadd "npm:sdata:_session:1", sessionid, defer err

	# set baseline fields
	await persistency.setSessionField sessionid, 'address', data.info.address + ':' + data.info.port, defer err
	await persistency.setSessionField sessionid, 'players', data.info.players + '/' + data.info.maxplayers, defer err

	await persistency.setSessionField sessionid, 'sid', sessionid, defer err
	await persistency.setSessionField sessionid, 'npid', npid, defer err

	# register the session with the connection
	await persistency.setConnField state, 'sessionid', sessionid, defer err

	# and send a reply
	sessionid64 = new int64(sessionid)

	state.reply REPLY_MESSAGE,
		result: 0
		sessionid: [ sessionid64.high32(), sessionid64.low32() ]