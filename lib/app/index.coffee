require 'html5-manifest'
require '../vendor'

# require 'ember'	# TODO
window.App = Ember.Application.create()

# io = require 'socket.io-client' # TODO convoy fails
socket = io.connect document.location.href

require('./services')(socket, App)

Handlebars.registerHelper 'date', (property, options) ->
	value = Ember.Handlebars.getPath @, property, options
	# moment = require 'moment'
	# moment(date).format('MMMM Do, YYYY')
	'Just a moment ago'	# TODO XXX

App.user = null
App.connect = Ember.Object.create
	email: null
	started: false
	start: ->
		_s = require 'underscore.string'
		if email = _s.trim @get('email')
			@set 'started', true
			# If only the username was typed make it a proper email.

			# validators = require('validator').validators	# TODO 'net' not found?
			validators = {}
			validators.isEmail = (email) ->
				_s = require 'underscore.string'
				_s.contains email, '@'

			if not validators.isEmail email
				email += '@redstar.com'
			socket.emit 'login', email, (redirect) ->
				if redirect
					return window.location.href = redirect
				App.get('router').send 'goUserProfile'	# TODO XXX set this up with the current user?


App.adapter = require('./adapter')(DS, socket)
App.store = DS.Store.create
	revision: 4
	adapter: App.adapter

require('./models')(DS, App)
require('./controllers')(Ember, App)
require('./router')(Ember, App)

App.initialize()
