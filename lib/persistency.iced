# redis 'persistency'/state sharing component
redis = require 'redis'

logger = require './logger.iced'

int64 = require 'int64-native'

# read base configuration
config = require('config').redis

if not config
	logger.error 'No Redis configuration found.'
	process.exit 1

# class definition
class Persistency
	constructor: ->
		# create the client
		@client = redis.createClient config.unixSocket or config.port or 6379, config.host or '127.0.0.1', config.options

		# error handler
		@client.on 'error', (err) =>
			logger.error 'error: %s\n%s', err.toString(), (err.stack or '').toString()

		# select the database
		@client.select config.database or 10, ->
			logger.info 'selected redis database %d', config.database or 10

	# initiate basic information for a connection
	newConnection: (remoteID, replyQueue, cb) -> 
		# connection ID (needs some code to prevent it going above the maximum value JS can handle, if anything interprets it as a number)
		await @client.incr 'npm:conn_id', defer err, connID

		# set the 'remote ID' for the connection
		await @client.hset "npm:conn:#{ connID }", 'remoteID', remoteID, defer err, reply

		# set the reply queue
		await @client.hset "npm:conn:#{ connID }", 'replyQueue', replyQueue, defer err, reply

		# and return to the callback
		cb connID.toString()

	# delete a connection's info
	deleteConnection: (connID, cb) ->
		await @client.expire "npm:conn:#{ connID }", 240, defer err

		cb err

	# connection field setter
	setConnField: (state, field, value, cb) ->
		await @client.hset "npm:conn:#{ state.token }", field, value, defer err, reply

		cb err

	# connection field getter
	getConnField: (state, field, cb) ->
		await @client.hget "npm:conn:#{ state.token }", field, defer err, reply

		cb err, reply

	# get user key name
	getUserKey: (npid, key) ->
		if Array.isArray npid
			npid = new int64(npid[0], npid[1]).toString()

		return "npm:user:#{ npid }" if not key

		return "npm:user:#{ npid }:#{ key }"

	# user field setter
	setUserField: (npid, field, value, cb) ->
		await @client.hset @getUserKey(npid), field, value, defer err, reply

		cb err

	# user field getter
	getUserField: (npid, field, cb) ->
		await @client.hget @getUserKey(npid), field, defer err, reply

		cb err, reply

	# session field setter
	setSessionField: (sid, field, value, cb) ->
		await @client.hset "npm:session:#{ sid }", field, value, defer err, reply

		cb err

	# session field getter
	getSessionField: (sid, field, sb) ->
		await @client.hget "npm:session:#{ sid }", field, defer err, reply

		cb err, reply

# return the class instance
module.exports = new Persistency()