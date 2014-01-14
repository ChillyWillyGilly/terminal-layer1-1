# message bus handler

# require uuid
uuid = require 'node-uuid'

# require amqp
amqp = require 'amqp'

# logger
logger = require './logger.iced'

# read base configuration
config = require('config').amqp

if not config
	logger.error 'No message bus configuration found.'
	process.exit 1

# message bus class
class MessageBus
	constructor: ->
		# connect based on the configuration
		@connection = amqp.createConnection(config)

		@connection.on 'ready', =>
			# some logs are nice
			logger.info 'amqp connected to %s', @connection.serverProperties.product

			@ready = true

	# function to wait until ready, or immediately call the cb
	onReady: (cb) ->
		if @ready
			cb()
			return

		@connection.on 'ready', =>
			cb()

	# gets a function to reply to the specified state
	getReplyFunction: (state) ->
		return (type, data) =>
			@connection.publish state.replyTo,
				data: data
				correlationId: state.id
				type: type

	# broadcasts a call on the service exchange
	broadcast: (type, data) ->
		await @getServiceExchange defer serviceExchange

		serviceExchange.publish '', data, 
			type: type

	# gets an exchange for background (callback) servicing
	getServiceExchange: (cb) ->
		@onReady =>
			if not @serviceExchange
				# get the named exchange for such
				await exchange = @connection.exchange 'npm-service',
					type: 'fanout'
					confirm: true
					durable: true
				, defer()

				@serviceExchange = exchange

			cb @serviceExchange

	# gets a queue listening on the service exchange
	getServiceQueue: (cb) ->
		@onReady =>
			if not @serviceQueue
				# get a queue
				await queue = @connection.queue 'npm-service-' + uuid.v4(),
					exclusive: true
				, defer()

				# bind on all topics
				queue.bind @serviceExchange, 'null'

				await queue.on 'queueBindOk', defer()

				@serviceQueue = queue

			cb @serviceQueue

	# sets up the RPC connection
	getRPCExchange: (cb) ->
		@onReady =>
			if not @rpcExchange
				# get the main named exchange
				await exchange = @connection.exchange 'npm-rpc', 
					type: 'topic'
					confirm: true
					durable: true
				, defer()

				@rpcExchange = exchange

			# call the callback
			cb @rpcExchange

	getRPCInputQueue: (topics, cb) ->
		@onReady =>
			if not @rpcInputQueue
				# get a queue
				await queue = @connection.queue 'npm-input-' + uuid.v4(),
					exclusive: true,
					durable: true
				, defer()

				# bind on all topics
				for topic in topics
					queue.bind @rpcExchange, topic

					await queue.on 'queueBindOk', defer()

				@rpcInputQueue = queue

			# and complete the callback
			cb @rpcInputQueue

	getRPCQueue: (cb) ->
		@onReady =>
			if not @rpcReplyQueue
				# get a local reply queue
				await queue = @connection.queue 'npm-reply-' + uuid.v4(),
					exclusive: true,
					durable: true
				, defer()

				@rpcReplyQueue = queue

			# call the callback
			cb @rpcReplyQueue

	getConnection: ->
		@connection

module.exports = new MessageBus()