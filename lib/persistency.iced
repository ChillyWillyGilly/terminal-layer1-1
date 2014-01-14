# redis 'persistency'/state sharing component
redis = require 'redis'

logger = require './logger.iced'

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
			logger.warn 'error from redis: %s', err

		# select the database
		@client.select config.database or 10, ->
			logger.info 'selected redis database %d', config.database or 10

	# initiate basic information for a connection
	newConnection: (remoteID, cb) -> 
		# connection ID (needs some code to prevent it going above the maximum value JS can handle, if anything interprets it as a number)
		await @client.incr 'npm:conn_id', defer err, connID

		# set the 'remote ID' for the connection
		await @client.hset "npm:conn:#{ connID }", 'remoteID', remoteID, defer err, reply

		# and return to the callback
		cb connID.toString()



# return the class instance
module.exports = new Persistency()