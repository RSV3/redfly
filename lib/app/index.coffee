_ = require 'underscore'
moment = require 'moment'


configureAdminOnLogin = (App, socket)->
	if not (cats = App.get 'admin.orgtagcats') then return		# wait for object to load
	if not (user = App.get 'user.id') then return				# need both admin and user loaded to be ready
	if App.user.get('stateManager.currentPath') is 'rootState.loading'
		return App.user.on 'didLoad', ->
			configureAdminOnLogin App, socket		# this needs to run after admin is loaded AND user logged in
	App.user.set 'lastLogin', new Date()
	App.store.commit()
	_.each _.map(cats.split(','), (t)-> t.trim()), (t, i)->
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
			document.cookie = "lastlogin=#{id};path=/;expires=" + moment().add(1, 'month').toDate().toUTCString()
			App.user.on 'didLoad', ->
				configureAdminOnLogin App, socket		# this needs to run after admin is loaded AND user logged in
		logout: ->
			App.set 'user', null
			# sometimes we logout after editing admin cfg, which loses the cio / goog flags
			# since the only purpose of these flags is to show the login correctly, let's reload.
			if App.admin.get('stateManager.currentPath') isnt 'rootState.loading' then App.admin.reload()
		logOnOut: ->
			document.cookie = "lastlogin=;path=/;expires=null"
			document.cookie = "connect.sid=;path=/;expires=null"
			App.auth.logout()


postHook = (Ember, DS, App, socket) ->
	require '../vendor/index.coffee'

	require('./templates.coffee') Ember
	require('./handlebars.coffee') Ember, Handlebars

	require('./ember.coffee') Ember, App

	require('./models.coffee') DS, App
	require('./controllers.coffee') Ember, App, socket
	require('./router.coffee') Ember, App, socket

	App.admin = Ember.ObjectProxy.create()
	App.set 'admin', App.Admin.find 1
	App.admin.on 'didLoad', ->
		configureAdminOnLogin App, socket		# this needs to run after admin is loaded AND user logged in

	socket.emit 'session', (session) ->
		if id = session.user
			App.auth.login id
		else
			App.auth.logout()
			App.advanceReadiness()


require('../../phrenetic/lib/app/index.coffee') preHook, postHook

