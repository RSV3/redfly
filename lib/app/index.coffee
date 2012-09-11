require 'html5-manifest'
require '../vendor'

# require 'ember'	# TODO


# io = require 'socket.io-client' # TODO
socket = io.connect document.location.href


# path = require 'path'
# views = path.dirname(path.dirname(__dirname)) + '/views/templates'

# views = '../../views/templates'	# TODO XXX why doesn't '+' work in require statements



App = Ember.Application.create()





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
	user: 178
	contact: 178
	subject: 'Poopty Peupty pants'
	dateSent: new Date






App.ApplicationView = Ember.View.extend
	templateName: 'application'
	# template: require '../../views/templates/application'
	didInsertElement: ->
		# TODO maybe do this without css selector if possible
		$('.search-query').addClear top: 6

		# TODO XXX do I want a loading indicator or not? See if it actually shows up first
		$("h1.loading").remove()
	_user: App.User.create()
App.ApplicationController = Ember.Controller.extend
	email: null
	connectStarted: false


App.HomeView = Ember.View.extend
	templateName: 'home'
	# template: require '../../views/templates/home'
	showConnect: false
	toggle: ->
		App.homeController.set 'showConnect', true
# App.HomeController = Ember.Controller.extend

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
		# 	linkHome: Ember.Route.transitionTo 'index'
		# 	linkTags: Ember.Route.transitionTo 'tags'
		# 	linkReport: Ember.Route.transitionTo 'contact'

		# tags: Ember.Route.extend
		# 	route: '/tags'
		# 	connectOutlets: (router) ->
		# 		router.get('applicationController').connectOutlet 'tags'
		
		# contact: Ember.Route.extend
		# 	route: '/contact/:contact_id'
		# 	connectOutlets: (router, contact) ->
		# 		router.get('applicationController').connectOutlet 'contact', contact


App.initialize()
