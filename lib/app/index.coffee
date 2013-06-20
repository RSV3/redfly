# require '../vendor'

require('phrenetic/lib/app') (Ember, DS, App, socket) ->
	# TODO Figure out a more permanent solution.
	templates = Ember.TEMPLATES

	templates.application = require '../../templates/application'

	templates.index = require '../../templates/home'
	templates.classify = require '../../templates/classify'
	templates._contact = require '../../templates/_contact'
	templates.contact = require '../../templates/contact'
	templates.contacts = require '../../templates/contacts'
	templates.create = require '../../templates/create'
	templates.import = require '../../templates/import'
	templates.leaderboard = require '../../templates/leaderboard'
	templates.profile = require '../../templates/profile'
	templates.report = require '../../templates/report'
	templates.tags = require '../../templates/tags'
	templates.results = require '../../templates/results'
	templates.dashboard = require '../../templates/dashboard'
	templates.admin = require '../../templates/admin'
	templates.companies = require '../../templates/companies'

	templates.filter = require '../../templates/sidebars/filter'
	templates.feed = require '../../templates/sidebars/feed'

	Ember.Handlebars.registerBoundHelper 'plusOne', (value, options) ->
		if typeof value == 'string'
			value = parseInt value, 10
		1 + value

	Ember.Handlebars.registerBoundHelper 'format', (value, options) ->
		'' + value.getDate() + '-' + (value.getMonth() + 1) + '-' + value.getFullYear()

	App.user = Ember.ObjectProxy.create()

	App.auth =
		login: (id) ->
			App.user.set 'content', App.User.find id
		logout: ->
			App.user.set 'content', null

	require('./models') DS, App
	require('./controllers') Ember, App, socket
	require('./router') Ember, App, socket

	App.admin = Ember.ObjectProxy.create()
	App.admin.set 'content', App.Admin.find 1

	socket.emit 'session', (session) ->
		if id = session.user
			App.auth.login id
			App.user.get('content').on 'didLoad', ->
				App.advanceReadiness()
				App.admin.set 'classifyCount', App.user.get 'classifyCount'
		else
			App.auth.logout()
			App.advanceReadiness()

