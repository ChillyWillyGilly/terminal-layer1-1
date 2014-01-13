module.exports = (data, state) ->
	state.reply 'RPCAuthenticateResultMessage',
		result: 2
		npid: [ 0, 0 ]
		sessionToken: new Buffer(16)