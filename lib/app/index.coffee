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







App.User = DS.Model.extend
	primaryKey: '_id'
	date: DS.attr 'date'
	email: DS.attr 'string'
	name: DS.attr 'string'

App.Contact = DS.Model.extend
	primaryKey: '_id'
	date: DS.attr 'date'
	name: DS.attr 'string'
	email: DS.attr 'string'
	addedBy: DS.belongsTo 'App.User'
	dateAdded: DS.attr 'date'
	knows: DS.hasMany 'App.User'
	tags: DS.hasMany 'App.Tag'
	notes: DS.hasMany 'App.Note'

App.Tag = DS.Model.extend
	primaryKey: '_id'
	date: DS.attr 'date'
	creator: DS.belongsTo 'App.User'
	body: DS.attr 'string'

App.Note = DS.Model.extend
	primaryKey: '_id'
	date: DS.attr 'date'
	author: DS.belongsTo 'App.User'
	body: DS.attr 'string'

# TODO XXX old history
# model.set 'history.178',
#         user: '178'
#         contact: '178'
#         first_email:
#           date: +new Date
#           subject: 'Poopty Peupty pants'
#         count: 47
App.Mail = DS.Model.extend
	primaryKey: '_id'
	date: DS.attr 'date'
	sender: DS.belongsTo 'App.User'
	recipient: DS.belongsTo 'App.Contact'
	subject: DS.attr 'string'
	dateSent: DS.attr 'date'

# App.User = Ember.Object.create
# 	id: 178
# 	date: new Date
# 	email: 'kbaranowski@redstar.com'
# 	name: 'Krzysztof Baranowski'

# App.Contact = Ember.Object.create
# 	id: 178
# 	date: new Date
# 	name: 'John Resig'
# 	email: 'john@name.com'
# 	addedBy: 178
# 	dateAdded: new Date
# 	knows: [ 178 ]
# 	tags: [ 'Sweet Tag Bro', 'VC' ]
# 	notes: [
# 		date: new Date
# 		author: 178
# 		text: 'Lorem ipsum dolor ist asdf asdfadf dasf adsf adsf adsf asdfads fads fads'
# 	]

# App.Mail = Ember.Object.create
# 	id: 178
# 	date: new Date
# 	sender: 178
# 	recipient: 178
# 	subject: 'Poopty Peupty pants'
# 	dateSent: new Date








getTypeName = (type) ->
	_.last type.toString().split('.')

App.adapter = DS.Adapter.create
	find: (store, type, id) ->
		socket.emit 'db', op: 'find', type: getTypeName(type), id: id, (data) ->
			store.load type, id, data

	findMany: (store, type, ids) ->
		socket.emit 'db', op: 'find', type: getTypeName(type), ids: ids, (data) ->
			store.load type, ids, data

	findQuery: (store, type, query, array) ->
		socket.emit 'db', op: 'find', type: getTypeName(type), query: query, (data) ->
			array.load data

	findAll: (store, type) ->
		socket.emit 'db', op: 'find', type: getTypeName(type), (data) ->
			store.load type, data

	createRecord: (store, type, model) ->
		socket.emit 'db', op: 'create', type: getTypeName(type), details: model.get('data'), (data) ->
			store.didCreateRecord model, data

	createRecords: (store, type, array) ->
		socket.emit 'db', op: 'create', type: getTypeName(type), details: array.mapProperty('data'), (data) ->
			store.didCreateRecords type, array, data # TODO must be in the same order

	updateRecord: (store, type, model) ->
		socket.emit 'db', op: 'save', type: getTypeName(type), details: model.get('data'), (data) ->
			store.didUpdateRecord model, data

	udpateRecords: (store, type, array) ->
		socket.emit 'db', op: 'save', type: getTypeName(type), details: array.mapProperty('data'), (data) ->
			store.didUpdateRecords type, array, data # TODO must be in the same order

	deleteRecord: (store, type, model) ->
		socket.emit 'db', op: 'remove', type: getTypeName(type), id: model.get('_id'), ->
			store.didDeleteRecord model

	deleteRecords: (store, type, array) ->
		socket.emit 'db', op: 'remove', type: getTypeName(type), ids: model.get('_id'), ->
			store.didDeleteRecords array




App.store = DS.Store.create
	revision: 4
	adapter: App.adapter










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
				App.get('router').send 'goUserProfile'	# TODO XXX set this up with the current user?

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

App.ProfileView = Ember.View.extend
	templateName: 'profile'
	# template: require '../../views/templates/profile'
App.ProfileController = Ember.ObjectController.extend()

App.TagsView = Ember.View.extend
	templateName: 'tags'
	# template: require '../../views/templates/tags'
App.TagsController = Ember.ArrayController.extend()

App.ReportView = Ember.View.extend
	templateName: 'report'
	# template: require '../../views/templates/report'
App.ReportController = Ember.Controller.extend()




App.Router = Ember.Router.extend
	root: Ember.Route.extend
		home: Ember.Route.extend
			route: '/'
			connectOutlets: (router) ->
				router.get('applicationController').connectOutlet 'home'

		userProfile: Ember.Route.extend
			route: '/profile'
			connectOutlets: (router) ->
				router.get('applicationController').connectOutlet 'profile', App.user
			goContact: Ember.Route.transitionTo 'contact'

		profile: Ember.Route.extend
			route: '/profile/:user_id'
			connectOutlets: (router, user) ->
				router.get('applicationController').connectOutlet 'profile', user
			goContact: Ember.Route.transitionTo 'contact'

		contact: Ember.Route.extend
			route: '/contact/:identity'
			connectOutlets: (router, contact) ->
				router.get('applicationController').connectOutlet 'contact', contact
			serialize: (router, context) ->
				identity: context.get 'email'
			deserialize: (router, params) ->
				# The 'identity' parameter can be a document id or an email. Emails make more meaningful forward-facing links.
				identity = params.identity
				if validators.isEmail identity
					return App.Contact.find(email: identity).objectAt 0
				App.Contact.find identity

		tags: Ember.Route.extend
			route: '/tags'
			connectOutlets: (router) ->
				router.get('applicationController').connectOutlet 'tags'

		report: Ember.Route.extend
			route: '/report'
			connectOutlets: (router) ->
				router.get('applicationController').connectOutlet 'report'

	# location: 'history'	# TODO Also rework server/index to serve index.html on any route (where currently "next new util.NotFound") WITHOUT
							# REDIRECTING (preserve the route for ember) and make all 3 error pages be part of ember somehow. Keep the server
							# error page however. Can I capture ember errors and serve a special page?
	enableLogging: true	# TODO

	goHome: Ember.Route.transitionTo 'home'
	goUserProfile: Ember.Route.transitionTo 'userProfile'
	goTags: Ember.Route.transitionTo 'tags'
	goReport: Ember.Route.transitionTo 'report'



App.initialize()
