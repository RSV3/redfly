
preHook = (Ember, DS, App, socket) ->
	App.user = Ember.ObjectProxy.create()
	App.auth =
		login: (id) ->
			App.set 'user', App.User.find id
		logout: ->
			App.set 'user', null



postHook = (Ember, DS, App, socket) ->
	require '../vendor'

	require('./templates') Ember
	require('./handlebars') Ember, Handlebars

	require('./ember') Ember, App

	require('./models') DS, App
	require('./controllers') Ember, App, socket
	require('./router') Ember, App, socket

	App.admin = Ember.ObjectProxy.create()
	App.admin.set 'content', App.Admin.find 1
	socket.emit 'session', (session) ->
		if id = session.user
			App.auth.login id
			App.user.on 'didLoad', ->
				App.advanceReadiness()
				App.admin.set 'classifyCount', App.user.get 'classifyCount'
		else
			App.auth.logout()
			App.advanceReadiness()



require('phrenetic/lib/app') preHook, postHook
