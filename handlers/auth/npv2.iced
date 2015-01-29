persistency = require '../../lib/persistency.iced'

getAuthModule = (id) ->
	if id == 1
		require "./ros.iced" # implicit return, the joys of people overdosing on caffeine
	else if id == 2
		require "./steam.iced"
	else
		null

amCache = {}
tokenId = 1

getCachedAuthModule = (id) ->
	amCache[id] = getAuthModule id unless amCache[id]

	amCache[id]

module.exports = (token, state, reply) ->
	if token.indexOf('npv2tkn:') != 0
		console.log 'invalid token: ' + token
		reply 2
		return

	# parse the token
	tokenObj = JSON.parse token.substring 8

	# define an array for identifier tokens
	identifiers = []

	# try to verify all tokens using their respective legacy modules
	for identPair in tokenObj
		# get the auth module
		authModule = getCachedAuthModule identPair[0]

		# bad details if not valid
		if not authModule
			reply 1
			return

		# invoke the auth module
		await authModule identPair[1], state, defer result, npid, sessionToken

		if result != 0
			console.log 'invalid result for ' + identPair[1]
			reply result
			return

		identifiers.push sessionToken

	# store the identifier list
	await persistency.setConnField state, 'identifiers', JSON.stringify(identifiers), defer err

	tokenId++
	reply 0, [ 0x1500001, tokenId ], 'npv2ids:' + JSON.stringify(identifiers)