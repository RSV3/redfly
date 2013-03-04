# require '../vendor'

require('phrenetic/lib/app') (Ember, DS, App, socket) ->
	# TODO Figure out a more permanent solution.
	templates = Ember.TEMPLATES
	templates.index = require '../../templates/home'
	templates.application = require '../../templates/application'
	templates.classify = require '../../templates/classify'
	templates.contact = require '../../templates/contact'
	templates.contacts = require '../../templates/contacts'
	templates.create = require '../../templates/create'
	templates.import = require '../../templates/import'
	templates.leaderboard = require '../../templates/leaderboard'
	templates.profile = require '../../templates/profile'
	templates.report = require '../../templates/report'
	templates.tags = require '../../templates/tags'
	templates.results = require '../../templates/results'
	templates.sort = require '../../templates/components/sort'

	#
	# oops! this isn't bindings aware, so is no help with pagination
	# once we do the ember upgrade, use this and remove the startplusone property on results pagination
	#
	Ember.Handlebars.registerBoundHelper 'plusOne', (value, options) ->
		#value = Ember.Handlebars.getPath @, property, options
		if typeof value == 'string'
			value = parseInt value, 10
		1 + value

	Ember.Handlebars.registerBoundHelper 'format', (value, options) ->		# TODO when we upgrade ember, make this registerBoundHelper
		#value = Ember.Handlebars.get @, property, options	# Note - this is not bindings aware: Doesn't work with profile page
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

	socket.emit 'session', (session) ->
		if id = session.user
			App.auth.login id
			App.user.get('content').on 'didLoad', ->
				App.advanceReadiness()
		else
			App.auth.logout()
			App.advanceReadiness()
