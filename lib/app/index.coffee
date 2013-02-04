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
	# TODO remove once I'm convinced this never happens
	alert 'Unable to establish connection, please refresh.'
	# window.location.reload()

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

App.adapter = require('./adapter') DS, socket
App.store = DS.Store.create
	revision: 6
	adapter: App.adapter

require('./ember') DS, App
require('./models') DS, App
require('./controllers') Ember, App, socket
require('./router') Ember, App, socket

socket.emit 'session', (session) ->
	if id = session.user
		App.auth.login id
	else
		App.auth.logout()
		
	App.initialize()


socket.on 'reloadApp', ->
	window.location.reload()
socket.on 'reloadStyles', ->
	stylesheet = $('link[href="/app.css"]')
	stylesheet.attr 'href', 'app.css?timestamp=' + Date.now()
