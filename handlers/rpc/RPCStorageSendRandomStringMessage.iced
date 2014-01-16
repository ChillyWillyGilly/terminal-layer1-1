# a compatible external application integration method
redisq = require 'redisq'

# read redis configuration
redisConfig = require('config').redis

if not redisConfig
	logger.error 'No Redis configuration found.'

	module.exports = () ->
	return

redisq.options
	redis:
		host: redisConfig.host or 'localhost'
		port: redisConfig.port or 6379

# libs
persistency = require '../../lib/persistency.iced'
messageBus = require '../../lib/messagebus.iced'
logger = require '../../lib/logger.iced'

int64 = require 'int64-native'

REPLY_MESSAGE = 'RPCStorageSendRandomStringMessage'

# read our configuration
externalConfig = require('config').externals

if not externalConfig
	logger.error 'No externals configuration found.'

	module.exports = () ->
	return

# get input queue
replyQueue = redisq.queue 'thresp'

replyQueue.process (task, done) ->
	try
		# reply state
		targetState = 
			id: { token: task.conn[0], id: task.conn[1] }
			token: task.conn[0]

		# get the reply queue used for the transport
		await persistency.getConnField targetState, 'replyQueue', defer err, replyTo

		targetState.replyTo = replyTo

		# send the reply
		replyFunc = messageBus.getReplyFunction targetState

		replyFunc REPLY_MESSAGE,
			randomString: JSON.stringify task.body
	catch error
		logger.error error.toString()

	done null
, 16

module.exports = (data, state) ->
	# get the connection npid
	await persistency.getConnField state, 'npid', defer err, npid

	# return if not authenticated
	return if not npid

	npid64 = new int64(parseInt(npid.substring(0, 8), 16), parseInt(npid.substring(8), 16))

	# get the data type
	str = data.randomString

	type = str.split(/\s/)[0]

	# check the server stuff for a random handler
	if not type of externalConfig
		logger.info 'Unknown type %s sent in random string.', type
		return

	# get the handler data
	typeData = externalConfig[type]

	# parse the actual data
	data = JSON.parse str.substring type.length + 1

	# do stuff for registering disconnect handlers
	await persistency.setConnField state, '__' + type, 'true', defer err

	# get the queue
	typeData.queueInstance = redisq.queue typeData.queue if not typeData.queueInstance

	# and send the dispatch
	typeData.queueInstance.push
		npid: npid.substring 1
		conn: [ state.id.token, state.id.id ]
		body: data