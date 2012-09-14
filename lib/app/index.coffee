require 'html5-manifest'
require '../vendor'

# require 'ember'	# TODO
window.App = Ember.Application.create()

# io = require 'socket.io-client' # TODO convoy fails
socket = io.connect document.location.href

Handlebars.registerHelper 'date', (property, options) ->
	value = Ember.Handlebars.getPath @, property, options
	# moment = require 'moment'
	# moment(date).format('MMMM Do, YYYY')
	'just a moment ago.'	# TODO XXX



App.auth = (id) ->
	if id
		App.set 'user', App.User.find id
	else if id is null
		App.set 'user', null
	else
		# TODO XXX lookup over websocket, set to null if none

App.user = null	# TODO XXX Also actually having this line is unessary, and possibly harmful. Wait, maybe necessary, what about unknownproperty. Does App.user have to be an ember object?
App.connect = Ember.Object.create
	email: ''
	started: false
# TODO XXX TRY WITHOUT ALL OF THIS AFTER AUTH IS WORKING

App.auth()






App.adapter = require('./adapter')(DS, socket)
App.store = DS.Store.create
	revision: 4
	adapter: App.adapter

require('./models')(DS, App)
require('./controllers')(Ember, App)
require('./router')(Ember, App, socket)

App.initialize()
