require 'html5-manifest'
require '../vendor'

# require 'ember'	# TODO also see if there's a way to get a debug version of node-ember like i'm using via script currently
window.App = Ember.Application.create()

# io = require 'socket.io-client' # TODO convoy fails
socket = io.connect document.location.href

Handlebars.registerHelper 'date', (property, options) ->
	value = Ember.Handlebars.getPath @, property, options	# TODO
	return value
	# moment = require 'moment'
	# moment(date).format('MMMM Do, YYYY')
	# '' + property.getDate() + '-' + (property.getMonth() + 1) + '-' + property.getFullYear()


App.user = Ember.ObjectProxy.create
	# TO-DO make these be on Application and Home views, respesctively
	loginIdentity: null
	signupIdentity: null

App.auth =
	login: (id) ->
		App.user.set 'content', App.User.find id
	logout: ->
		App.user.set 'content', null


App.adapter = require('./adapter')(DS, socket)
App.store = DS.Store.create
	revision: 4
	adapter: App.adapter

require('./models')(DS, App)
require('./controllers')(Ember, App, socket)
require('./router')(Ember, App, socket)


socket.emit 'session', (session) ->
	if id = session.user
		App.auth.login id
	else
		App.auth.logout()

	# TODO XXX XXX worst hack of all time
	setTimeout ->
		App.initialize()
	, 500
