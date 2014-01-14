# entry point for service processes

logger = require('../lib/logger.iced')

# configuration reading
config = require('config').services

if not config
	logger.error 'no services section in config'
	process.exit 1

# we need the message bus too
messageBus = require '../lib/messagebus.iced'

{EventEmitter} = require 'events'

class ServiceHandler extends EventEmitter
	constructor: (@queue) ->
		# subscribe to our queue
		@queue.subscribe { ack: true }, (m, headers, deliveryInfo) =>
			type = deliveryInfo.type

			try
				@emit type, m
			catch e
				logger.error 'error processing %s: %s\n%s', deliveryInfo.type, e, (e.stack or '').toString()

			# acknowledge the packet
			queue.shift false

run = (mode) ->
	subset = mode.subset

	# if this isn't an array, make it one
	if not Array.isArray subset
		subset = [subset]

	# handlers
	services = []

	for entry in subset
		# check the subset
		if not config[entry]
			logger.error 'unconfigured subset %s in service', subset
			process.exit 1

		if Array.isArray config[entry]
			services = services.concat(config[entry])
		else
			services.push(config[entry])

	# get the exchange
	await messageBus.getServiceExchange defer exchange

	await messageBus.getServiceQueue defer queue

	# define a service handler
	serviceHandler = new ServiceHandler(queue)

	# include service handlers
	for service in services
		try
			ep = require "./#{ service }.iced"
			ep.initialize serviceHandler
		catch e
			logger.error 'error initializing %s: %s', service, e.toString()

module.exports.run = run