persistency = require '../lib/persistency.iced'

# read configuration

externalConfig = require('config').externals

if not externalConfig
	logger.error 'No externals configuration found for externals handler.'
	process.exit 1

# setup redisq
redisq = require 'redisq'

# read redis configuration
redisConfig = require('config').redis

if not redisConfig
	logger.error 'No Redis configuration found.'
	process.exit 1

redisq.options
	redis:
		host: redisConfig.host or 'localhost'
		port: redisConfig.port or 6379

# service
class ExternalsService
	initialize: (handler) ->
		handler.on 'client_close', (data) =>
			await persistency.getConnField { token: data.connID }, 'npid', defer err, npid

			# for all registered externals
			for type, cdata of externalConfig
				validity = null

				# get if the user ever used this service
				await persistency.getConnField { token: data.connID }, '__' + type, defer err, validity

				# if not, don't bother
				continue if not validity

				# get the queue
				cdata.queueInstance = redisq.queue cdata.queue if not cdata.queueInstance

				# and send the dispatch
				cdata.queueInstance.push
					npid: npid.substring 1
					conn: [ data.connID, 0 ]
					body:
						type: 'disconnect'


module.exports = new ExternalsService()