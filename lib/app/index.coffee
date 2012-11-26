require '../vendor'

# require 'ember'	# TODO also see if there's a way to get a debug version of node-ember like i'm using via script currently
window.App = Ember.Application.create autoinit: false

# site = require('url').parse window.location.href
# io = require 'socket.io-client' # TODO convoy fails
# socket = io.connect site.protocol + '//' + site.host
socket = io.connect(window.location.protocol + "//" + window.location.hostname + (window.location.port and ":" + window.location.port))
socket.on 'error', ->
	window.location.reload()

# Handlebars.registerHelper 'date', (property, options) ->
# 	value = Ember.Handlebars.getPath @, property, options	# TODO is this bindings aware? Doesn't work with profile page
# 	return value
# 	# moment = require 'moment'
# 	# moment(date).format('MMMM Do, YYYY')
# 	# '' + property.getDate() + '-' + (property.getMonth() + 1) + '-' + property.getFullYear()

Handlebars.registerHelper 'debug', (optionalValue) ->
	console.log 'Current Context'
	console.log '===================='
	console.log @
	if optionalValue
		console.log 'Value'
		console.log '===================='
		console.log optionalValue


App.user = Ember.ObjectProxy.create
	classifyCount: 0
	# TO-DO make these be on Application and Home views, respesctively
	loginIdentity: null
	signupIdentity: null

App.auth =
	login: (id) ->
		App.user.set 'content', App.User.find id
	logout: ->
		App.user.set 'content', null


App.adapter = require('./adapter') DS, socket
App.store = DS.Store.create
	revision: 6
	adapter: App.adapter
	
App.refresh = (record) ->
	App.store.findQuery record.constructor, record.get('id')
App.filter = (type, sort, query, filter) ->
	records = type.filter query, filter
	sort.asc ?= true
	options =
		content: records
		sortProperties: [sort.field]
		sortAscending: sort.asc
	Ember.ArrayProxy.create Ember.SortableMixin, options


require('./models') DS, App
require('./controllers') Ember, App, socket
require('./router') Ember, App, socket


socket.emit 'session', (session) ->
	if id = session.user
		App.auth.login id
	else
		App.auth.logout()
		
	App.initialize()
