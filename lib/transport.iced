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

	addConnection: (connection) ->
		@connections[connection.connID] = connection

		connection.on 'close', =>
			delete @connections[connection.connID]

	sendRPC: (connection, message) ->
		# publish to the message queue
		@rpcExchange.publish message.type, message.data,
			correlationId: JSON.stringify({ id: message.id, token: connection.connID })
			replyTo: @rpcQueue.name

class TransportConnection extends EventEmitter
	constructor: (@transport, @remoteID) ->
		@transport.addConnection this

		@on 'message', (message) =>
			@handleMessage(message)

		persistency.newConnection @remoteID, (@connID) =>

	handleMessage: (message) ->
		@transport.sendRPC this, message

	sendMessage: (type, id, message) ->
		logger.warn 'TransportConnection.sendMessage not overridden'

module.exports =
	Transport: Transport
	TransportConnection: TransportConnection