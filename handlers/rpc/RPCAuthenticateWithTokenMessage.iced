logger = require '../../lib/logger.iced'

auth = require '../auth-shared.iced'

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
		auth.handleAuthReply state, result, npid, token

	# check if the authentication method is loaded
	return replyAuth 2 if not authMethod

	state.source = config.method

	authMethod new Buffer(data.token, 'base64').toString(), state, replyAuth