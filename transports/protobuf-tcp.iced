# protobuf/TCP transport, similar to the original NP transports

{Transport, TransportConnection} = require '../lib/transport.iced'
MESSAGE_SIGNATURE = 0xDEADC0DE

logger = require '../lib/logger.iced'

# check for configuration
config = require('config').transports

if not config or not config.protobuf_tcp
	logger.error 'No configuration for protobuf-tcp transport.'
	process.exit 1

# requires
net = require 'net'
fs = require 'fs'
{Protobuf} = require 'node-protobuf'

# protobuf desc file
pb = new Protobuf(fs.readFileSync config.protobuf_tcp.desc)

# and generated messagedefinition
{pids, pnames, snames} = require './protobuf-ids.iced'

# transport class
class ProtobufTCPTransport extends Transport
	constructor: ->
		# create the server
		@server = net.createServer (socket) ->
			# connection class instance
			conn = new ProtobufTCPConnection(socket.remoteAddress)

			# call our binding method
			conn.bindTo(socket)

		@server.listen(config.protobuf_tcp.port)

class ProtobufTCPConnection extends TransportConnection
	bindTo: (socket) ->
		# data callback
		socket.on 'data', (buf) =>
			# safety check #1, any length (0 == disconnect)
			if buf.length > 0
				read = buf.length # bytes read from this packet
				origin = 0 # offset to start reading from

				# while there's data in this packet
				while read > 0
					# if this is a new packet (state == null/undefined)					
					if not @messageState
						return if buf.length < (origin + 16) # if there's not enough packet for a header, bail out
						
						# read the header (rpc_message_header_s in current libnp)
						@messageHeader =
							signature: buf.readUInt32LE origin  # signature, to not accidentally read corrupted data
							length: buf.readUInt32LE origin + 4 # length of data
							type: buf.readUInt32LE origin + 8 # message 'type' identifier
							id: buf.readUInt32LE origin + 12 # async call identifier

						# check if signature matches
						if @messageHeader.signature != MESSAGE_SIGNATURE
							logger.info 'Signature mismatch from %s', @remoteID

							return

						# set message state so we can start reading
						@messageState = 
							totalBytes: @messageHeader.length
							readBytes: 0 # obviously

							messageBuffer: new Buffer(@messageHeader.length) # we read to this
							messageType: @messageHeader.type # convenience
							messageID: @messageHeader.id

						# decrement read count
						read -= 16
						origin += 16

						# end of block, note how reading continues even if this is a new packet

					# read the payload
					copyLen = Math.min read, @messageState.totalBytes - @messageState.readBytes

					# arguments are targetBuffer, targetOffset, sourceStart, sourceEnd
					buf.copy @messageState.messageBuffer, @messageState.readBytes, origin, origin + copyLen

					# increment counters
					@messageState.readBytes += copyLen
					origin += copyLen
					read -= copyLen

					# and the obligatory 'did we get a full message' check
					if @messageState.readBytes >= @messageState.totalBytes
						# message state, whatever
						@parseMessage @messageState

						# so we know to expect a new header
						@messageState = null

		# error callback
		socket.on 'error', (err) =>
			logger.info err

	parseMessage: (state) ->
		try
			# parse the message data for the sent id
			messageData = pb.Parse(state.messageBuffer, snames[state.messageType])

			@emit 'message', 
				id: state.messageID
				type: pnames[state.messageType]
				data: messageData

		catch error
			logger.warn error.toString()


new ProtobufTCPTransport()