# These values get subbed in by the build process.
process.env.NODE_ENV = '[NODE_ENV]'
process.env.HOST = '[HOST]'

require '../vendor'


# TraceKit.report.subscribe (stacktrace) ->
# 	# TODO log the stacktrace, logged in user, and router path
# 	console.log stacktrace

# Ember.onerror = (err) ->
# 	alert 'asdf'
# 	console.log err

window.App = Ember.Application.create autoinit: false

io = require 'socket.io-client'
socket = io.connect require('./util').baseUrl
socket.on 'error', ->
	window.location.reload()

Handlebars.registerHelper 'truncatedate', (property, options) ->
	value = Ember.Handlebars.getPath @, property, options	# TODO is this bindings aware? Doesn't work with profile page
	moment = require 'moment'
	m = moment(value).format('MMMM Do, YYYY')
	d = '' + value.getDate() + '-' + (value.getMonth() + 1) + '-' + value.getFullYear()
	return d

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
	if id = session.passport.user
		App.auth.login id
	else
		App.auth.logout()
		
	App.initialize()


socket.on 'reloadStyles', ->
	stylesheet = $('link[href="/app.css"]')
	stylesheet.attr 'href', 'app.css?timestamp=' + Date.now()
