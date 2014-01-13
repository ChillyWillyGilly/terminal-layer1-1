# base transport class for transport implementations
{EventEmitter} = require 'events'

logger = require './logger.iced'

# include the message bus
messageBus = require './messagebus.iced'

class Transport extends EventEmitter
	constructor: ->
		# connection list
		@connections = []

		# message stuff
		messageBus.getRPCExchange (@rpcExchange) =>

		messageBus.getRPCQueue (@rpcQueue) =>

		# connect handler
		@on 'connect', (connection) =>

	addConnection: (connection) ->
		# TODO: replace with actual connection id instead of remoteID
		@connections[connection.remoteID] = connection

		connection.on 'close', =>
			delete @connections[connection.remoteID]

	sendRPC: (connection, message) =>
		@rpcExchange.publish message.type, message.data,
			correlationId: JSON.stringify({ id: message.id, token: connection.remoteID })
			replyTo: @rpcQueue.name

class TransportConnection extends EventEmitter
	constructor: (@transport, @remoteID) ->
		#await persistency.getConnID @remoteID, defer @connID

		@on 'message', (message) =>
			@handleMessage(message)

	handleMessage: (message) ->
		@transport.sendRPC this, message

module.exports =
	Transport: Transport
	TransportConnection: TransportConnection