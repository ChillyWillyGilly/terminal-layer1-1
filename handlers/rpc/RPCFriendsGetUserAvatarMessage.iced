persistency = require '../../lib/persistency.iced'

int64 = require 'int64-native'

REPLY_MESSAGE = 'RPCFriendsGetUserAvatarResultMessage'

replyFunc = (state, result, uid, data) ->
	state.reply REPLY_MESSAGE, 
		result: result,
		guid: uid,
		fileData: data or new Buffer(1)
		_buffer: 'fileData'

fs = require 'fs'
defaultAvatar = fs.readFileSync 'data/noavatar.png'

module.exports = (data, state) ->
	# get the connection npid
	await persistency.getConnField state, 'npid', defer err, npid

	# if not connected, ignore
	return replyFunc state, 2, data.guid if not npid

	npid64 = new int64(0x1100001, data.guid)

	# read the file
	await fs.readFile 'data/avatars/' + npid64.toString() + '.png', defer err, avatarData

	# return the avatar
	replyFunc state, 0, data.guid, defaultAvatar if err
	replyFunc state, 0, data.guid, avatarData if not err