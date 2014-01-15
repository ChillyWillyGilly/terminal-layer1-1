# base transport class for transport implementations
{EventEmitter} = require 'events'

logger = require './logger.iced'

# include the message bus
messageBus = require './messagebus.iced'

# include persistency
persistency = require './persistency.iced'

class Transport extends EventEmitter
	constructor: ->
		# connection list
		@connections = []

		# message stuff
		messageBus.getRPCExchange (@rpcExchange) =>

		messageBus.getRPCQueue (@rpcQueue) =>
			# subscribe, indeed
			@rpcQueue.subscribe { ack: true }, (m, headers, deliveryInfo) =>
				@rpcQueue.shift false

				try
					correlationId = m.correlationId
					msgType = m.type

					if not correlationId.token of @connections
						logger.info 'attempted to reply to invalid connection %s', correlationId.token
						return

					connection = @connections[correlationId.token]

					connection.sendMessage(msgType, correlationId.id, m.data)
				catch e
					logger.warn 'error on reply handler: %s', e.toString()

		# connect handler
		@on 'connect', (connection) =>

	# add a connection to the connection list
	addConnection: (connection) ->
		# array
		@connections[connection.connID] = connection

		# and a close handler
		connection.on 'close', =>
			# remove persistent data
			# TODO: this should actually be done after a timeout (redis EXPIRE command?)
			await persistency.deleteConnection connection.connID, defer err

			# run a callback
			messageBus.broadcast 'client_close', 
				connID: connection.connID

			# and delete the array index
			delete @connections[connection.connID]

	sendRPC: (connection, message) ->
		# publish to the message queue
		@rpcExchange.publish message.type, message.data,
			correlationId: JSON.stringify({ id: message.id, token: connection.connID })
			replyTo: @rpcQueue.name

class TransportConnection extends EventEmitter
	constructor: (@transport, @remoteID) ->
		# add a message hander
		@on 'message', (message) =>
			@handleMessage(message)

		# and register with persistency
		persistency.newConnection @remoteID, @transport.rpcQueue.name, (@connID) =>
			# register with the transport
			@transport.addConnection this

			# registered, do callback stuff
			@registered = true

			@emit 'register'

	# wait until registered with persistency
	waitForRegister: (cb) ->
		return cb() if @registered

		@on 'register', cb

	# basically we just send RPC here
	handleMessage: (message) ->
		await @waitForRegister defer()

		@transport.sendRPC this, message

	# base implementation
	sendMessage: (type, id, message) ->
		logger.warn 'TransportConnection.sendMessage not overridden'

module.exports =
	Transport: Transport
	TransportConnection: TransportConnection