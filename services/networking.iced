# support for obtaining TURN server credentials for the NPNetworking API

redisq = require 'redisq'
inQueue = redisq.queue 'int-networking'
outQueue = redisq.queue 'thresp'

logger = require '../lib/logger.iced'

crypto = require 'crypto'

# configuration
networkingEnabled = false

config = require('config').p2prelay

if config
	networkingEnabled = config.enabled

class NetworkingService
	initialize: (handler) ->
		inQueue.process (task, done) =>
			# process the disabled case
			if not networkingEnabled
				outQueue.push
					conn: task.conn
					body:
						error: 'Relaying is not activated on this server.'

				done null

				return

			# process the actual credential creation
			logger.info 'received p2p relay request from', task.npid

			# username and expiration timestamp
			username = task.npid
			timestamp = Math.floor(new Date().getTime() / 1000) + (config.expiryTime or (3600 * 24))

			# rfc5766-turn-server temporary user/password details
			retUsername = timestamp + ":" + username

			hash = crypto.createHmac 'sha1', config.hmacKey # note how this is a hmac, not a hash
			hash.update retUsername

			retPassword = hash.digest 'base64'

			# formulate a return value
			outQueue.push
				conn: task.conn
				body:
					username: retUsername
					password: retPassword
					server: 'turn:' + config.turnServer.host + ':' + config.turnServer.port

			done null
		, 16

module.exports = new NetworkingService()