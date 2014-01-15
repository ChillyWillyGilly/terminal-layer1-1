persistency = require '../lib/persistency.iced'

class AuthService
	initialize: (handler) ->
		handler.on 'client_close', (data) =>
			await persistency.getConnField { token: data.connID }, 'npid', defer err, npid

			await persistency.client.lrem persistency.getUserKey(npid, 'conns'), 0, data.connID, defer err

module.exports = new AuthService()