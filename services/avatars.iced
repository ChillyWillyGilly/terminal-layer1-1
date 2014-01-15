fs = require 'fs'
easyimage = require 'easyimage'
request = require 'request'

logger = require '../lib/logger.iced'
persistency = require '../lib/persistency.iced'

class AvatarService
	initialize: (handler) ->
		# register a handler
		handler.on 'user_authenticated', (data) =>
			if data.source == 'discourse'
				@fetchAvatar data.npid

		# create data/	
		await fs.exists 'data', defer exists

		if not exists
			await fs.mkdir 'data', defer()

		# create data/avatars/
		await fs.exists 'data/avatars', defer exists

		if not exists
			await fs.mkdir 'data/avatars', defer()

	fetchAvatar: (npid) ->
		# get the field stored by the auth service
		await persistency.getUserField npid, 'avatar_url', defer err, avatar_url

		# request the avatar
		await request
			url: avatar_url
			encoding: null
		, defer error, response, body

		# error checks
		return if error

		return if response.statusCode != 200

		# write the file
		contentType = response.headers['content-type']

		path = 'data/avatars/' + npid
		path += '.jpg' if contentType == 'image/jpeg'
		path += '.gif' if contentType == 'image/gif'
		path += '.png' if contentType == 'image/png'

		# actually write it
		await fs.writeFile path, body, defer error

		# return if there's an error
		return if error

		# convert if it's a jpeg image
		if contentType == 'image/jpeg' or contentType == 'image/gif'
			await easyimage.convert
				src: path
				dst: path.replace('.jpg', '.png').replace '.gif', '.png'
				quality: 10
			, defer err, image

			path = path.replace('.jpg', '.png').replace '.gif', '.png'

		# and log it
		logger.info 'stored avatar %s', path

module.exports = new AvatarService()