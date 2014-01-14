persistency = require '../../lib/persistency.iced'
logger = require '../../lib/logger.iced'

# config
config = require('config').auth

if not config or not config.discourse
	logger.error 'no configuration for discourse authentication'
else
	discourseURL = config.discourse.url

# request module
request = require 'request'

module.exports = (token, state, reply) ->
	return reply 2 if not discourseURL

	# add the client cookie
	jar = request.jar()
	cookie = request.cookie '_t=' + token

	jar.add cookie

	# request the 'user_preferences' redirect
	await request
		url: "#{ discourseURL }user_preferences"
		jar: jar
		followRedirect: false
	, defer error, response, body

	# error?
	if error
		logger.error error
		return reply 2

	# this should be a redirect, so is this one?
	if response.statusCode != 301 and response.statusCode != 302
		logger.warn 'non-redirect status code from discourse auth'
		return reply 2

	# as this redirects to /users/[name]/preferences, we need to match that from the url
	match = response.headers.location.match /\/users\/(.*?)\/preferences/

	# not a match? probably a bad token
	if not match
		logger.info 'invalid authentication token: %s', token
		return reply 1

	# request the actual user details
	await request
		url: "#{ discourseURL }users/#{ match[1] }.json"
		jar: jar
	, defer error, response, body

	# again, error?
	if error
		logger.error error
		return reply 2

	data = JSON.parse body

	# store avatar data
	npid = [ 0x1100001, data.user.id ]

	avatar_url = 'http:' + data.user.avatar_template.replace('{size}', '90')

	await persistency.setUserField npid, 'discourse_id', data.user.id, defer err
	await persistency.setUserField npid, 'avatar_url', avatar_url, defer err

	logger.info 'completed authentication request for discourse user %d', data.user.id

	reply 0, npid, new Buffer(token)