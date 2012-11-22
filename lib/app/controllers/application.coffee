module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'
	util = require '../../util'


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
				tabs = ['classify', 'leaderboard', 'contacts', 'tags']
				for tab in tabs
					@set 'at' + _s.capitalize(tab), false
				@set 'at' + _s.capitalize(state), true
			).observes 'App.router.currentState.name'
		didInsertElement: ->
			socket.on 'feed', (data) =>
				item = Ember.ObjectProxy.create
					content: App.get(data.type).find data.id
				item['type' + data.type] = true
				@get('controller.feed').unshiftObject item

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
