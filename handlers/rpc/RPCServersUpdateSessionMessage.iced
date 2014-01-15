persistency = require '../../lib/persistency.iced'

messageBus = require '../../lib/messagebus.iced'

service = require '../../services/sessions.iced'

int64 = require 'int64-native'

REPLY_MESSAGE = 'RPCServersUpdateSessionResultMessage'

module.exports = (data, state) ->
	# get the connection npid
	await persistency.getConnField state, 'npid', defer err, npid

	# return an error if not authenticated
	if not npid
		state.reply REPLY_MESSAGE,
			result: 1
			sessionid: ''

		return

	await persistency.getConnField state, 'sessionid', defer err, sessionid

	if not sessionid
		state.reply REPLY_MESSAGE,
			result: 1
			sessionid: ''

		return

	if sessionid
		await service.deleteSession sessionid, state.token, defer err

	# create the session
	await service.createSession sessionid, npid, data.info, defer err

	# and send a reply
	sessionid64 = new int64(sessionid)

	state.reply REPLY_MESSAGE,
		result: 0
		sessionid: [ sessionid64.high32(), sessionid64.low32() ]