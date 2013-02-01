module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'


	App.ApplicationController = Ember.Controller.extend
		feed: (->
				mutable = []
				@get('_initialContacts').forEach (contact) ->
					item = Ember.ObjectProxy.create content: contact
					item.typeInitialContact = true
					mutable.push item
				mutable
			).property '_initialContacts.@each'
		_initialContacts: (->
				App.Contact.find
					conditions:
						added: $exists: true
					options:
						sort: added: -1
						limit: 5
			).property()


	App.ApplicationView = Ember.View.extend
		template: require '../../../views/templates/application'

		changeActiveTab: (->
				state = App.get 'router.currentState.name'
				tabs = ['create', 'classify', 'import', 'leaderboard', 'contacts', 'tags']
				for tab in tabs
					@set 'at' + _s.capitalize(tab), false
				@set 'at' + _s.capitalize(state), true
			).observes 'App.router.currentState.name'

		didInsertElement: ->
			# setTimeout ->
			# 		throw new Error 'penis penis'
			# 	, 3000
			socket.on 'feed', (data) =>
				type = data.type
				model = type
				if type is 'Linkedin'
					model = 'Contact'

				item = Ember.ObjectProxy.create
					content: App.get(model).find data.id
				item['type' + _s.capitalize(type)] = true
				if type is 'Linkedin'
					item['updater'] = App.User.find data.updater
				@get('controller.feed').unshiftObject item

			# Update contacts if they recieve additional linkedin data.
			socket.on 'linked', (changes) =>
				changes = _.filter changes, (change) ->
					App.store.recordIsLoaded App.Contact, change
				if not _.isEmpty changes
					App.adapter.findMany App.store, App.Contact, changes

			# TO-DO Maybe create a pattern for the simple use case of using a socket to get and set one value.
			socket.emit 'summary.contacts', (count) =>
				@set 'controller.contactsQueued', count
			socket.emit 'summary.tags', (count) =>
				@set 'controller.tagsCreated', count
			socket.emit 'summary.notes', (count) =>
				@set 'controller.notesAuthored', count
			socket.emit 'summary.verbose', (verbose) =>
				@set 'controller.mostVerboseTag', verbose
			socket.emit 'summary.user', (user) =>
				@set 'controller.mostActiveUser', user

		feedItemView: Ember.View.extend
			classNames: ['feed-item']
			didInsertElement: ->
				@$().addClass 'animated flipInX'

		spotlightSearchView: App.SearchView.extend
			tagName: 'li'
			select: (event) ->
				App.get('router').send 'goContact', event.context
