module.exports = (preHook, postHook) ->

	require '../vendor/index.coffee'

	CONFIG_VARIABLES

	# inject the store into all components and views, so can lookup there
	Ember.onLoad 'Ember.Application', (Application) ->
		Application.initializer
			name: "injectStoreIntoComponentsAndViews",
			after: "store",
			initialize: (container, application) ->
				application.inject('component', 'store', 'store:main')
				application.inject('view', 'store', 'store:main')


	window.App = Ember.Application.create
		LOG_TRANSITIONS: process.env.NODE_ENV is 'development'
	App.deferReadiness()
	App.ready = ->
		$('#initializing').remove()

	io = require 'express.io/node_modules/socket.io/node_modules/socket.io-client'
	socket = io.connect require('./util.coffee').baseUrl
	socket.on 'error', ->
		# TODO remove once I'm convinced this never happens
		alert 'Unable to establish connection, please refresh.'
		# window.location.reload()
	socket.on 'reloadApp', -> window.location.reload()
	socket.on 'reloadStyles', -> App.styles.set 'timestamp', Date.now()

	preHook? Ember, DS, App, socket

	App.addObserver 'title', ->
		title = App.get 'title'
		document.title = title
		# $('meta[property="og:title"]').attr 'content', title

	App.styles = do ->
		Styles = Ember.Object.extend
			updateSheet: (->
					href = '/' + @get('name') + '.css'
					if timestamp = @get('timestamp')
						href += '?timestamp=' + timestamp
					$('#styles').attr 'href', href
				).observes 'name', 'timestamp'
		Styles.create()

	require('./store.coffee') Ember, DS, App, socket
	require('./ember.coffee') Ember, DS, App
	require('./handlebars.coffee') Ember, Handlebars

	postHook? Ember, DS, App, socket

