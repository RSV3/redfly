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

		results: Ember.ObjectProxy.create()
		showResults: (->
				# TODO check the substructure of results to make sure there actually are some.
				@get('usingSearch') and @get('results.content')
			).property 'results.@each', 'usingSearch'
		searchChanged: (->
				query = util.trim App.get('search')
				if not query
					@set 'results.content', null
				else
					socket.emit 'search', query, (results) =>
						@set 'results.content', {}
						for type, ids of results
							model = 'Contact'
							if type is 'tag' or type is 'note'
								model = _s.capitalize type
							@set 'results.' + type, App[model].find _id: $in: ids
			).observes 'App.search'


	App.ApplicationView = Ember.View.extend
		template: require '../../../views/templates/application'
		didInsertElement: ->
			$('.navbar-search i[rel=popover]').popover()	# TO-DO make scoped @$ when possible and make the selector just [rel=popover]

			socket.on 'feed', (data) =>
				item = Ember.ObjectProxy.create
					content: App.get(data.type).find data.id
				item['type' + data.type] = true
				@get('controller.feed').unshiftObject item

			# TODO Maybe create a pattern for the simple use case of using a socket to get and set one value.
			socket.emit 'summary.contacts', (count) =>
				@set 'controller.contactsAdded', count
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

		searchView: Ember.View.extend
			tagName: 'li'
			classNames: ['dropdown']
			attributeBindings: ['role']
			role: 'menu'
			keyDown: (event) ->
				if event.which is 13	# Enter.
					_.defer => @set 'controller.usingSearch', false
				if event.which is 27	# Escape.
					@$(':focus').blur()
			focusIn: ->
				@set 'controller.usingSearch', true
			focusOut: ->
				# Determine the newly focused element and see if it's anywhere inside the search view. If not, hide the results (after a small delay
				# in cause of mousedown).
				setTimeout =>
						focused = $(document.activeElement)
						if not _.first @$().has(focused)
							@set 'controller.usingSearch', false
					, 150

			searchBoxView: Ember.TextField.extend()
