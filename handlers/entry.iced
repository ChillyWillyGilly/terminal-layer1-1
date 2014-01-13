# entry point for 'rpc handler' processes

logger = require('../lib/logger.iced')

# configuration reading
config = require('config').handlers

if not config
	logger.error 'no handlers section in config'
	process.exit 1

# we need the message bus too
messageBus = require '../lib/messagebus.iced'

run = (mode) ->
	subset = mode.subset

	# if this isn't an array, make it one
	if not Array.isArray subset
		subset = [subset]

	# handlers
	handlers = []

	for entry in subset
		# check the subset
		if not config[entry]
			logger.error 'unconfigured subset %s in handler', subset
			process.exit 1

		if Array.isArray config[entry]
			handlers = handlers.concat(config[entry])
		else
			handlers.push(config[entry])

	# get the exchange
	await messageBus.getRPCExchange defer exchange

	await messageBus.getRPCInputQueue handlers, defer queue

	queue.subscribe { ack: true }, (m, headers, deliveryInfo) ->
		console.log m
		console.log deliveryInfo

		queue.shift false


module.exports.run = run