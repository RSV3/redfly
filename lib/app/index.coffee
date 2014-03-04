_ = require 'underscore'
moment = require 'moment'
socketemit = require './socketemit.coffee'

configureAdminOnLogin = _.after 2, (App)->

	App.user.set 'lastLogin', new Date()
	App.user.save()
	App.admin?.set 'extensionOn', $('.redfly-flag-extension-is-loaded').length
	cats = App.get 'admin.orgtagcats'
	_.each _.map(cats.split(','), (t)-> t.trim()), (t, i)->
		App.admin.set "orgtagcat#{i+1}", t
	user = App.get 'user.id'
	socketemit.get "classifyCount/#{user}", (count) ->		# always update these counts.
		App.admin.set 'classifyCount', count
		socketemit.get "requestCount/#{user}", (count)->
			App.admin.set 'requestCount', count
			App.advanceReadiness()

store = null
preHook = (Ember, DS, App) ->
	App.set 'user', null
	App.auth =
		login: (id) ->
			store.find('user', id).then (data)->
				if data
					App.set 'user', data
					document.cookie = "lastlogin=#{id};path=/;expires=" + moment().add(1, 'month').toDate().toUTCString()
					configureAdminOnLogin App		# this needs to run after admin is loaded AND user logged in
		logout: ->
			App.set 'user', null
			App.admin?.reload()
		logOnOut: ->
			document.cookie = "lastlogin=;path=/;expires=null"
			document.cookie = "connect.sid=;path=/;expires=null"
			App.auth.logout()

postHook = (Ember, DS, App) ->
	Ember.Application.initializer
		name: 'test'
		after: 'store'
		initialize: (container)->
			store = container.lookup 'store:main'
			App.set 'admin', null
			require '../vendor/index.coffee'
			require('./templates.coffee') Ember
			require('./handlebars.coffee') Ember, Handlebars
			require('./ember.coffee') Ember, App
			require('./models.coffee') DS, App
			require('./controllers.coffee') Ember, App
			require('./router.coffee') Ember, App
			store.find('admin', 1).then (data)->
				if data
					App.set 'admin', data
					configureAdminOnLogin App		# this needs to run after admin is loaded AND user logged in

			socketemit.get 'session', (session) ->
				if id = session?.user then App.auth.login id
				else
					App.auth.logout()
					App.advanceReadiness()

require('../../phrenetic/lib/app/index.coffee') preHook, postHook

