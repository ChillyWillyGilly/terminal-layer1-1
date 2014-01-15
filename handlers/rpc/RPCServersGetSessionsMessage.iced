persistency = require '../../lib/persistency.iced'

messageBus = require '../../lib/messagebus.iced'

service = require '../../services/sessions.iced'

int64 = require 'int64-native'

REPLY_MESSAGE = 'RPCServersGetSessionsResultMessage'

FETCH_SCRIPT = "local fkeys = redis.call('sinter', unpack(KEYS))
local r = {}
for i, key in ipairs(fkeys) do
  r[#r+1] = redis.call('hgetall','npm:session:' .. key)
  r[#r].sid = key
end
return r"

module.exports = (data, state) ->
	# get the connection npid
	await persistency.getConnField state, 'npid', defer err, npid

	# return an error if not authenticated
	if not npid
		state.reply REPLY_MESSAGE,
			servers: []

		return

	# make a query list of keys
	data.infos = [{ key: 'session', value: '1' }] if data.infos.length == 0
	
	baseQuery = [ FETCH_SCRIPT, 0 ]

	for info in data.infos
		# ignore 'array' checks (we'll do those later)
		continue if info.value[0] == '['
			
		baseQuery.push "npm:sdata:_#{ info.key }:#{ info.value }"

	# set the key size
	baseQuery[1] = baseQuery.length - 2

	# query redis for the matching fields
	await persistency.client.eval baseQuery, defer err, sessions

	# map the session data to hashes
	tempsessions = []

	for session in sessions
		tempsession = {}

		# map normal keys/values
		for i in [0..session.length] by 2
			# prevent 'undefined' from being passed
			continue if not session[i]
			continue if not session[i + 1]

			# add the key
			tempsession[session[i]] = session[i + 1]

		# map unified keys/values
		matchKeys = {}

		for k, v of tempsession
			k = k.substring(1) if k[0] == '_'

			matchKeys[k] = v

		tempsession.matchKeys = matchKeys

		# add to the list
		tempsessions.push tempsession

	sessions = tempsessions

	# apply array checks
	for i in [sessions.length-1..0] by -1
		session = sessions[i]

		for info in data.infos
			# is this an array check?
			continue if info.value[0] != '['

			# parse the array
			arr = JSON.parse info.value

			match = false

			# for through it
			for v in arr
				# if one item matches
				if info.key of session.matchKeys and session.matchKeys[info.key] == v
					match = true
					break

			# if this is no match
			sessions.splice i if not match

	# return the session list
	servers = []

	for session in sessions
		npid64 = new int64(parseInt(session.npid.substring(0, 8), 16), parseInt(session.npid.substring(8), 16))
		sessionid64 = 

		server = 
			address: session.address.split(':')[0]
			port: session.address.split(':')[1]
			npid: [ npid64.high32(), npid64.low32() ]
			players: session.players.split('/')[0]
			maxplayers: session.players.split('/')[1]
			sid: session.sid

		server.data = []

		# get custom infos
		for k, v of session
			continue if k[0] != '_'

			server.data.push
				key: k.substring 1
				value: v

		servers.push server

	# reply back with servers
	state.reply REPLY_MESSAGE,
		servers: servers