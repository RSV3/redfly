# require '../vendor'

require('phrenetic/lib/app') (Ember, DS, App, socket) ->

	Handlebars.registerHelper 'format', (property, options) ->		# TODO when we upgrade ember, make this registerBoundHelper
		value = Ember.Handlebars.getPath @, property, options	# Note - this is not bindings aware: Doesn't work with profile page
		'' + value.getDate() + '-' + (value.getMonth() + 1) + '-' + value.getFullYear()

	App.user = Ember.ObjectProxy.create
		classifyCount: 0

	App.auth =
		login: (id) ->
			App.user.set 'content', App.User.find id
		logout: ->
			App.user.set 'content', null

	require('./models') DS, App
	require('./controllers') Ember, App, socket
	require('./router') Ember, App, socket

	socket.emit 'session', (session) ->
		if id = session.user
			App.auth.login id
		else
			App.auth.logout()
		App.initialize()
