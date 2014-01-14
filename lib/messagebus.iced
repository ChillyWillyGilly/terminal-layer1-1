# message bus handler

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

	getReplyFunction: (state) ->
		return (type, data) =>
			@connection.publish state.replyTo,
				data: data
				correlationId: state.id
				type: type

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
				await queue = @connection.queue '',
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
				await queue = @connection.queue '',
					exclusive: true,
					durable: true
				, defer()

				@rpcReplyQueue = queue

			# call the callback
			cb @rpcReplyQueue

	getConnection: ->
		@connection

module.exports = new MessageBus()