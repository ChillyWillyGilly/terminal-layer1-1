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
		@client = redis.createClient config.unixSocket or config.port or 6379, config.host or '127.0.0.1', config.options

		@client.on 'error', (err) =>
			logger.warn 'error from redis: %s', err

		@client.select config.database or 10, ->
			logger.info 'selected redis database %d', config.database or 10

	newConnection: (remoteID, cb) -> 
		await @client.incr 'npm:conn_id', defer err, connID

		await @client.hset "npm:conn:#{ connID }", 'remoteID', remoteID, defer err, reply

		cb connID.toString()



# return the class instance
module.exports = new Persistency()