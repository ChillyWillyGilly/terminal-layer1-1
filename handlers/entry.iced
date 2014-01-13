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

	# subscribe to our queue
	queue.subscribe { ack: true }, (m, headers, deliveryInfo) ->
		# load the handler
		try
			handler = require "./rpc/#{ deliveryInfo.routingKey }.iced"
		catch e
			logger.error 'error loading %s: %s', deliveryInfo.routingKey, e.toString()

		if handler
			correlationId = JSON.parse deliveryInfo.correlationId

			# set up state
			state =
				id: correlationId
				token: correlationId.token
				replyTo: deliveryInfo.replyTo
			
			state.reply = messageBus.getReplyFunction state

			# call the handler
			try
				handler m, state
			catch e
				logger.error 'error processing %s (correlationId %s): %s\n%s', deliveryInfo.routingKey, JSON.stringify(correlationId), e, (e.stack or '').toString()

		# acknowledge the packet
		queue.shift false


module.exports.run = run