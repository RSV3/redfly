require 'html5-manifest'
require '../vendor'

# require 'ember'	# TODO

_ = require 'underscore'
_s = require 'underscore.string'
# validators = require('validator').validators	# TODO 'net' not found?
validators = {}
validators.isEmail = (email) ->
	_s.contains email, '@'


# io = require 'socket.io-client' # TODO convoy fails
socket = io.connect document.location.href

socket.on 'login', (id) ->
	App.user = App.User.find id
socket.on 'logout', ->
	App.user = null


# path = require 'path'
# views = path.dirname(path.dirname(__dirname)) + '/views/templates'

# views = '../../views/templates'	# TODO XXX why doesn't '+' work in require statements



window.App = Ember.Application.create()

Handlebars.registerHelper 'date', (property, options) ->
	value = Ember.Handlebars.getPath @, property, options
	# moment = require 'moment'
	# moment(date).format('MMMM Do, YYYY')
	'a date!'	# TODO XXX




App.User = Ember.Object.extend
	id: 178
	date: new Date
	email: 'kbaranowski@redstar.com'
	name: 'Krzysztof Baranowski'

App.Contact = Ember.Object.extend
	id: 178
	date: new Date
	name: 'John Resig'
	email: 'john@name.com'
	addedBy: 178
	dateAdded: new Date
	knows: [ 178 ]
	tags: [ 'Sweet Tag Bro', 'VC' ]
	notes: [
		date: new Date
		author: 178
		text: 'Lorem ipsum dolor ist asdf asdfadf dasf adsf adsf adsf asdfads fads fads'
	]

# TODO XXX old history
# model.set 'history.178',
#         user: '178'
#         contact: '178'
#         first_email:
#           date: +new Date
#           subject: 'Poopty Peupty pants'
#         count: 47
App.Mail = Ember.Object.extend
	id: 178
	date: new Date
	sender: 178
	recipient: 178
	subject: 'Poopty Peupty pants'
	dateSent: new Date








App.connect = Ember.Object.create
	email: null
	started: false
	start: ->
		if email = _s.trim @get('email')
			@set 'started', true
			# If only the username was typed make it a proper email.
			if not validators.isEmail email
				email += '@redstar.com'
			socket.emit 'login', email, (redirect) ->
				if redirect
					return window.location.href = redirect
				App.get('router').send 'showProfile'	# TODO XXX set this up with the current user?

# App.user = App.User.create()
App.user = null






App.ApplicationView = Ember.View.extend
	templateName: 'application'
	# template: require '../../views/templates/application'
	didInsertElement: ->
		# TODO maybe do this without css selector if possible
		$('.search-query').addClear top: 6

		# TODO XXX do I want a loading indicator or not? See if it actually shows up first
		$('h1.loading').remove()
App.ApplicationController = Ember.Controller.extend()




App.HomeView = Ember.View.extend
	templateName: 'home'
	# template: require '../../views/templates/home'
	toggle: ->
		@get('controller').set 'showConnect', true
App.HomeController = Ember.Controller.extend
	showConnect: false

App.ContactView = Ember.View.extend
	templateName: 'contact'
	# template: require '../../views/templates/contact'
App.ContactController = Ember.ObjectController.extend()

# App.TagsView = Ember.View.extend
# 	templateName: 'tags'
# 	# template: require '../../views/templates/tags'
# App.TagsController = Ember.ArrayController.extend()




App.Router = Ember.Router.extend
	enableLogging: true	# TODO
	root: Ember.Route.extend
		home: Ember.Route.extend
			route: '/'
			connectOutlets: (router) ->
				router.get('applicationController').connectOutlet 'home'
		# 	goHome: Ember.Route.transitionTo 'index'
		# 	goTags: Ember.Route.transitionTo 'tags'
		# 	goReport: Ember.Route.transitionTo 'contact'

		# profile: Ember.Route.extend
		# 	route: '/contact/:contact_id'
		# 	connectOutlets: (router, contact) ->
		# 		router.get('applicationController').connectOutlet 'contact', contact

		# tags: Ember.Route.extend
		# 	route: '/tags'
		# 	connectOutlets: (router) ->
		# 		router.get('applicationController').connectOutlet 'tags'
		
		# contact: Ember.Route.extend
		# 	route: '/contact/:contact_id'
		# 	connectOutlets: (router, contact) ->
		# 		router.get('applicationController').connectOutlet 'contact', contact


App.initialize()
