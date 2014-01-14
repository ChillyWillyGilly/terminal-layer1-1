persistency = require '../../lib/persistency.iced'

module.exports = (data, state) ->
	token = data.token.toString()

	
	state.reply 'RPCAuthenticateResultMessage',
		result: 2
		npid: [ 0, 0 ]
		sessionToken: new Buffer(16)