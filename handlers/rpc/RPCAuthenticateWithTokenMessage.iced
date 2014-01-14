persistency = require '../../lib/persistency.iced'
logger = require '../../lib/logger.iced'

# config
config = require('config').auth

if not config
	logger.error 'no configuration for client authentication'

	config = {}

# load the authentication method
try
	authMethod = require "../auth/#{ config.method }.iced"
catch e
	logger.error 'error loading %s: %s', config.method, e.toString()

module.exports = (data, state) ->
	# handy reply function
	replyAuth = (result, npid, token) ->
		# TODO: handle state setting related to authentication

		npid = npid or [ 0, 0 ]
		token = token or new Buffer(16)

		state.reply 'RPCAuthenticateResultMessage',
			result: result
			npid: npid
			sessionToken: token

	# check if the authentication method is loaded
	return replyAuth 2 if not authMethod

	authMethod new Buffer(data.token).toString(), state, replyAuth