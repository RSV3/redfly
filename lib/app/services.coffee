module.exports = (socket, App) ->

	socket.on 'login', (id) ->
		App.user = App.User.find id

	socket.on 'logout', ->
		App.user = null
