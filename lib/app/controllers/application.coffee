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

			# TODO Maybe create a pattern for the simple use case of using a socket to get and set one value.
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

		searchView: Ember.View.extend
			tagName: 'li'
			classNames: ['dropdown']
			didInsertElement: ->
				$(@$('[rel=popover]')).popover()
			attributeBindings: ['role']
			role: 'menu'
			showResults: (->
					# TODO check the substructure of results to make sure there actually are some.
					@get('usingSearch') and @get('controller.results.content')
				).property 'controller.results.@each', 'usingSearch'
			keyUp: (event) ->
				if event.which is 13	# Enter.
					@set 'usingSearch', false
				if event.which is 27	# Escape.
					@$(':focus').blur()
			focusIn: ->
				@set 'usingSearch', true
			focusOut: ->
				# Determine the newly focused element and see if it's anywhere inside the search view. If not, hide the results (after a small delay
				# in case of mousedown).
				setTimeout =>
						focused = $(document.activeElement)
						if not _.first @$().has(focused)
							@set 'usingSearch', false
					, 150

			searchBoxView: Ember.TextField.extend
				valueChanged: (->
						query = util.trim @get('value')
						if not query
							@set 'controller.results.content', null
						else
							socket.emit 'search', query, (results) =>
								@set 'controller.results.content', {}
								for type, ids of results
									model = 'Contact'
									if type is 'tag' or type is 'note'
										model = _s.capitalize type
									@set 'controller.results.' + type, App[model].find _id: $in: ids
					).observes 'value'
