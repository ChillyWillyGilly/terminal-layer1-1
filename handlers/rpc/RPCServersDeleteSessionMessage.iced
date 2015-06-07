persistency = require '../../lib/persistency.iced'

messageBus = require '../../lib/messagebus.iced'

service = require '../../services/sessions.iced'

int64 = require 'int64-native'

REPLY_MESSAGE = 'RPCServersDeleteSessionResultMessage'

module.exports = (data, state) ->
	# get the connection npid
	await persistency.getConnField state, 'npid', defer err, npid

	# return an error if not authenticated
	if not npid
		state.reply REPLY_MESSAGE,
			result: 1

		return

	await persistency.getConnField state, 'sessionid', defer err, sessionid

	if not sessionid
		state.reply REPLY_MESSAGE,
			result: 1

		return

	await service.deleteSession sessionid, state.token, defer err

	state.reply REPLY_MESSAGE,
		result: 0