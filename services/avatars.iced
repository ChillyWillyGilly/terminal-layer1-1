class AvatarService
	initialize: (handler) ->
		handler.on 'user_authenticated', (data) =>
			if data.source == 'discourse'
				@fetchAvatar data.npid

	fetchAvatar: (npid) ->
		console.log 'boo! ', npid

module.exports = new AvatarService()