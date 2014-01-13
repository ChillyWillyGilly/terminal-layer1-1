# base transport class for transport implementations
{EventEmitter} = require 'events'

class Transport extends EventEmitter
	constructor: ->
		# connect handler
		@on 'connect', (connection) =>


class TransportConnection extends EventEmitter
	constructor: (@remoteID) ->
		#await persistency.getConnID @remoteID, defer @connID

		@on 'message', (message) =>
			@handleMessage(message)

	handleMessage: (message) ->
		console.log message

module.exports =
	Transport: Transport
	TransportConnection: TransportConnection