require 'html5-manifest'
require '../vendor'

# require 'ember'	# TODO also see if there's a way to get a debug version of node-ember like i'm using via script currently
window.App = Ember.Application.create()

# io = require 'socket.io-client' # TODO convoy fails
socket = io.connect document.location.href

Handlebars.registerHelper 'date', (property, options) ->
	value = Ember.Handlebars.getPath @, property, options
	# moment = require 'moment'
	# moment(date).format('MMMM Do, YYYY')
	'just a moment ago.'	# TODO XXX



App.authenticate = (id) ->
	if id
		App.set 'user', App.User.find id
	else if id is null
		App.set 'user', null
	else
		console.log 'no-arg authenticate'
		# TODO XXX lookup over websocket, set to null if none

App.user = null	# TODO XXX Also actually having this line is unessary, and possibly harmful. Wait, maybe necessary, what about unknownproperty. Does App.user have to be an ember object?
App.connect = Ember.Object.create	# TODO make this not be shared between login and signup since they're different now. Maybe still grey out both buttons.
	email: ''
	started: false

begin = (fn) ->
	_s = require 'underscore.string'
	if email = _s.trim App.connect.get 'email'
		App.connect.set 'started', true

		# validators = require('validator').validators	# TODO 'net' not found?
		validators = {}
		validators.isEmail = (email) ->
			_s = require 'underscore.string'
			_s.contains email, '@'

		# If only the username was typed make it a proper email.
		if not validators.isEmail email
			email += '@redstar.com'
		fn email

App.auth =
	login: ->
		begin (email) ->
			socket.emit 'login', email, (id) ->
				App.authenticate id
				App.connect.set 'email', ''
				App.connect.set 'started', false
				App.get('router').send 'goUserProfile'

	logout: ->
		socket.emit 'logout', ->
			App.authenticate null
			App.get('router').send 'home'

	signup: ->
		begin (email) ->
			socket.emit 'signup', email, (authorizeUrl) ->
				App.connect.set 'email', ''
				App.connect.set 'started', false				
				window.location.href = authorizeUrl




App.adapter = require('./adapter')(DS, socket)
App.store = DS.Store.create
	revision: 4
	adapter: App.adapter

require('./models')(DS, App)
require('./controllers')(Ember, App)
require('./router')(Ember, App, socket)

App.authenticate()

App.initialize()
