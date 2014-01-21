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
		await
			for key, value of reply
				continue if key.substring(0, 1) != '_'

				persistency.client.srem "npm:sdata:#{ key }:#{ value }", sid, defer err

			persistency.client.srem "npm:sdata:_session:1", sid, defer err

			persistency.client.del "npm:session:#{ sid }", defer err

			persistency.client.hdel "npm:conn:#{ token }", 'sessionid', defer err

		cb err

	createSession: (sessionid, npid, info, cb) ->
		# set extended fields
		await
			for field in info.data
				persistency.setSessionField sessionid, '_' + field.key, field.value, defer err

				persistency.client.sadd "npm:sdata:_#{ field.key }:#{ field.value }", sessionid, defer err

			persistency.client.sadd "npm:sdata:_session:1", sessionid, defer err

			# set baseline fields
			persistency.setSessionField sessionid, 'address', info.address + ':' + info.port, defer err
			persistency.setSessionField sessionid, 'players', info.players + '/' + info.maxplayers, defer err

			persistency.setSessionField sessionid, 'sid', sessionid, defer err
			persistency.setSessionField sessionid, 'npid', npid, defer err

		cb err

module.exports = new SessionsService()