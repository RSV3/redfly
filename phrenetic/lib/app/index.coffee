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

	preHook? Ember, DS, App

	App.addObserver 'title', ->
		title = App.get 'title'
		document.title = title
		# $('meta[property="og:title"]').attr 'content', title

	App.styles = do ->
		Styles = Ember.Object.extend
			updateSheet: (->
				href = "/#{@get('name')}.css"
				if timestamp = @get('timestamp')
					href += '?timestamp=' + timestamp
				$('#styles').attr 'href', href
			).observes 'name', 'timestamp'
		Styles.create()

	require('./store.coffee') Ember, DS, App
	require('./ember.coffee') Ember, DS, App
	require('./handlebars.coffee') Ember, Handlebars

	postHook? Ember, DS, App

