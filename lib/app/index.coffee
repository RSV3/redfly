
_ = require 'underscore'


configureAdminOnLogin = (socket)->
	if not (cats = App.admin.get 'orgtagcats') then return		# wait for object to load
	if not (user = App.user.get 'id') then return				# need both admin and user loaded to be ready
	if cats.split	# rewrite categories string as an array
		App.admin.set 'orgtagcats', _.map cats.split(','), (t)-> t.trim()
		_.each App.admin.get('orgtagcats'), (t, i)->
			App.admin.set "orgtagcat#{i+1}", t
	socket.emit 'classifyCount', user, (count) ->		# always update these counts.
		App.admin.set 'classifyCount', count
		socket.emit 'requestCount', user, (count)->
			App.admin.set 'requestCount', count
			App.advanceReadiness()

preHook = (Ember, DS, App, socket) ->
	App.user = Ember.ObjectProxy.create()
	App.auth =
		login: (id) ->
			App.set 'user', App.User.find id
			App.user.on 'didLoad', ->
				configureAdminOnLogin socket		# this needs to run after admin is loaded AND user logged in
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
	App.set 'admin', App.Admin.find 1
	App.admin.on 'didLoad', ->
		configureAdminOnLogin socket		# this needs to run after admin is loaded AND user logged in
	socket.emit 'session', (session) ->
		if id = session.user
			App.auth.login id
		else
			App.auth.logout()
			App.advanceReadiness()



require('phrenetic/lib/app') preHook, postHook
