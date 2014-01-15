persistency = require '../lib/persistency.iced'

class SessionsService
	initialize: (handler) ->
		# register a handler
		handler.on 'client_close', (data) =>
			await persistency.getConnField { token: data.connID }, 'sessionid', defer err, sessionid

			await @deleteSession sessionid, data.connID, defer err

	deleteSession: (sid, token, cb) ->
		await persistency.client.hgetall "npm:session:#{ sid }", defer err, reply

		# return in case of error
		return cb err if err

		# loop through all fields so we can get rid of the relational map
		for key, value of reply
			continue if key.substring(0, 1) != '_'

			await persistency.client.srem "npm:sdata:#{ key }:#{ value }", sid, defer err

		await persistency.client.srem "npm:sdata:_session:1", sid, defer err

		await persistency.client.del "npm:session:#{ sid }", defer err

		await persistency.client.hdel "npm:conn:#{ token }", 'sessionid', defer err

		cb err

module.exports = new SessionsService()