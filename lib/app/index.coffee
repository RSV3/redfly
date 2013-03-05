# require '../vendor'

require('phrenetic/lib/app') (Ember, DS, App, socket) ->

	#
	# oops! this isn't bindings aware, so is no help with pagination
	# once we do the ember upgrade, use this and remove the startplusone property on results pagination
	#
	Handlebars.registerHelper 'plusOne', (property, options) ->
		value = Ember.Handlebars.getPath @, property, options
		if typeof value == 'string'
			value = parseInt value, 10
		1 + value

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
