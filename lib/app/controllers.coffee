module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'
	util = require '../util'

	# TO-DO
	# path = require 'path'
	# views = path.dirname(path.dirname(__dirname)) + '/views/templates'
	# views = '../../views/templates'
	# template: require '../../views/templates/application'


	App.ApplicationView = Ember.View.extend
		template: require '../../views/templates/application'
		didInsertElement: ->
			# TODO addclear

			$('.navbar-search i').popover()	# TO-DO make scoped @$ when possible

			socket.on 'feed', (data) =>
				item = Ember.ObjectProxy.create
					content: App.get(data.type).find data.id
				item['type' + data.type] = true
				# TODO remove
				# setTimeout (->
				# 			console.log item.get 'body'
				# 			console.log item.get 'creator'
				# 			# console.log item.get('creator').get 'name'
				# 			# setTimeout (-> console.log(item.get('creator').get('name')) ), 1000
				# 		), 1000
				@get('controller.feed').unshiftObject item
		feedItemView: Ember.View.extend
			classNames: ['feed-item']
			didInsertElement: ->
				@$().addClass 'animated flipInX'
	App.ApplicationController = Ember.Controller.extend
		feed: (->
				mutable = []
				@get('_initialContacts').forEach (contact) ->
					item = Ember.ObjectProxy.create content: contact
					item['typeInitialContact'] = true
					mutable.push item
				mutable
			).property '_initialContacts.@each'
		_initialContacts: (->
				App.Contact.find
					# TODO XXX XXX but test first
					# conditions:
					# 	dateAdded: $exists: true
					options:
						sort: '-date'
						limit: 3
			).property()
		results: Ember.ObjectProxy.create()
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
							@set 'results.' + type, App[model].find _id: $in: ids # TO-DO this should probably be a call to findMany maybe
			).observes 'App.search'


	App.HomeView = Ember.View.extend
		template: require '../../views/templates/home'
		classNames: ['home']
		toggle: ->
			@get('controller').set 'showConnect', true
	App.HomeController = Ember.Controller.extend()

	App.ContactView = Ember.View.extend
		template: require '../../views/templates/contact'
		classNames: ['contact']
		newNoteView: Ember.TextArea.extend
			attributeBindings: ['placeholder', 'rows']
			placeholder: (->
					'Tell a story about ' + @get('controller.nickname') + ', describe a secret talent, whatever!'
				).property 'controller.nickname'
			rows: 3
		noteView: Ember.View.extend
			tagName: 'blockquote'
			didInsertElement: ->
				if @get 'controller.animate'
					@set 'controller.animate', false
					@$().addClass 'animated flipInX'
	App.ContactController = Ember.ObjectController.extend
		currentNote: null
		firstHistory: (->
				@get('_histories').objectAt 0
			).property '_histories.@each'
		historyCount: (->
				@get '_histories.length'
			).property '_histories.@each'
		_histories: (->
				App.Mail.find
					conditions:
						sender: App.user.get 'id'
						recipient: @get 'id'
					options:
						sort: 'date'
			).property 'content'
		isKnown: (->
				# TO-DO there has to be better way to do 'contains'
				has = false
				@get('knows').forEach (user) ->
					if user.get('id') is App.user.get('id')
						has = true
				has
			).property 'knows.@each'
		disableAdd: (->
				if util.trim @get('currentNote')
					return false
				return true
			).property 'currentNote'
		emptyNotesText: (->
				if Math.random() < 0.9
					# return 'No notes about ' + @get('nickname') + ' yet.'	# TO-DO doesn't work?
					return 'No notes about this contact yet.'
				('...and that\'s why you ' +
					' <a href="http://www.dailymotion.com/video/xrjyfz_that-s-why-you-always-leave-a-note_shortfilms" target="_blank">' +
					 'always leave a note!</a>'
				).htmlSafe()
			).property().volatile()
		add: ->
			if note = util.trim @get('currentNote')
				newNote = App.store.createRecord App.Note,	# TODO will this work as App.Note.createRecord? Change here and elsewhere.
					author: App.user
					contact: @get 'content'
					body: note
				App.store.commit()
				@set 'animate', true
				@get('notes').unshiftObject newNote
				@set 'currentNote', null

		classifying: (->
				window.document.location.href.indexOf('classify') isnt -1
			).property().volatile()
		next: ->
			if not @get 'dateAdded'
				@set 'dateAdded', new Date
				@set 'addedBy', App.user
			# TODO XXX save. Make sure that adapter/api work
			App.user.set 'classifyIndex', (App.user.get('classifyIndex') or 0) + 1 # TODO

			index = App.user.get 'classifyIndex'
			contact = App.user.get('classify').objectAt index

			@set 'content', contact



	App.ProfileView = Ember.View.extend
		template: require '../../views/templates/profile'
		classNames: ['profile']
	App.ProfileController = Ember.ObjectController.extend
		# contacts: (-> App.Contact.find addedBy: @get('id'))	# TODO XXX XXX
		contacts: (-> App.Contact.find())
			.property('content').volatile()
		total: (-> @get('contacts.length'))
			.property 'contacts.@each'

	App.TagsView = Ember.View.extend
		template: require '../../views/templates/tags'
		classNames: ['tags']
	App.TagsController = Ember.ArrayController.extend()

	App.ReportView = Ember.View.extend
		template: require '../../views/templates/report'
		classNames: ['report']
	App.ReportController = Ember.Controller.extend()


	App.TaggerView = Ember.View.extend
		template: require '../../views/templates/tagger'
		classNames: ['tagger']
		tags: (->
				mutable = []
				@get('_rawTags').forEach (tag) ->
					mutable.push tag
				mutable
			).property '_rawTags.@each'
		_rawTags: (->
				App.Tag.find contact: @get('contact.id'), category: @get('category')
			).property('contact')
		click: (event) ->
			# @get('newTagView').$().focus() # TO-DO, maybe using the view on 'event'?
			@$('.new-tag').focus()
		add: (event) ->
			if tag = util.trim @get('currentTag')
				existingTag = _.find @get('tags'), (otherTag) =>	# TODO is fat-arrow necessary?
					tag is otherTag	# TODO this doesn't work, but this should: tag is otherTag.get('body')
				if not existingTag
					newTag = App.store.createRecord App.Tag,
						creator: App.user
						contact: @get 'contact'
						category: @get('category') or 'industry'
						body: tag
					App.store.commit()
					@set 'animate', true
					@get('tags').pushObject newTag
				else
					# TODO find the element of the tag and play the appropriate animation
					# probably make it play faster, like a mac system componenet bounce. And maybe play a sound.
					# existingTag/@$().addClass 'animated pulse'
				@set 'currentTag', null
		tagView: Ember.View.extend
			tagName: 'span'
			classNames: ['tag']
			search: ->
				App.set 'search', 'tag:' + @get('context.body')
			delete: (event) ->
				tag = @get 'context'
				$(event.target).parent().addClass 'animated rotateOutDownLeft' # TO-DO icky, why doesn't the scoped jquery work? @$
				setTimeout =>
						@get('parentView.tags').removeObject tag # Timing for animation. This would be unnecessary except 'tags' is currently a copy.
					, 1000
				tag.deleteRecord()
				App.store.commit()
			didInsertElement: ->
				if @get 'parentView.animate'
					@set 'parentView.animate', false
					@$().addClass 'animated bounceIn'
			willDestroyElement: ->
				# TO-DO do this and change the icky code in 'add': http://stackoverflow.com/questions/9925171/deferring-removal-of-a-view-so-it-can-be-animated
				# @$().addClass 'animated rotateOutDownLeft'
		newTagView: Ember.TextField.extend
			classNames: ['new-tag-field']
			currentTagBinding: 'parentView.currentTag'
			currentTagChanged: (->
					if tag = @get('currentTag')
						@set 'currentTag', tag.toLowerCase()
					@$().attr 'size', 2 + @get('currentTag.length') # TODO Different characters have different widths, so this isn't super accurate.
				).observes 'currentTag'


	App.LoaderView = Ember.View.extend	# TO-DO does this have to be on the App object?
		template: require '../../views/templates/loader'

		didInsertElement: ->
			$('#signupMessage').modal()	# TO-DO make scoped @$ when possible
			@set 'loading', $.pnotify
				title: 'Email parsing status',
				text: '<div id="loading"></div>'
				type: 'info'
				# nonblock: true
				hide: false
				closer: false
				sticker: false
				icon: 'icon-envelope'
				animate_speed: 700
				opacity: 0.9
				animation:
					effect_in: 'drop'
					options_in: direction: 'up'
					effect_out: 'drop'
					options_out: direction: 'right'
				before_open: (pnotify) =>
					pnotify.css top: '60px'
					@$('#loadingStarted').appendTo '#loading'
			@set 'stateConnecting', true

			socket.emit 'parse', App.user.get('id'), =>
				@get('loading').effect 'bounce'
				@get('loading').pnotify type: 'success', closer: true
				App.User.find id: App.user.get('id')	# Classify queue has been determined and saved on the server, refresh by querying the store.
				@set 'stateDone', true
				@set 'stateParsing', false

			socket.on 'parse.total', (total) =>
				@set 'current', 0
				@set 'total', total
				@set 'stateParsing', true
				@set 'stateConnecting', false
			socket.on 'parse.name', =>
				App.User.find id: App.user.get('id')	# We just figured out the logged-in user's name, refesh by querying the store.
			socket.on 'parse.update', =>
				@incrementProperty 'current'

		percent: (->
				current = @get 'current'
				total = @get 'total'
				percentage = 0
				if current and total
					percentage = Math.round (current / total) * 100
				'width: ' + percentage + '%;'
			).property 'current', 'total'



	# TO-DO define 'connected' and 'canConnect' like derby does.
	App.ConnectionView = Ember.View.extend	# TO-DO probably inline this in appview # TO-DO does this have to be on the App object?
		template: require '../../views/templates/connection'
		classNames: ['connection']
		connect: ->
			# Hide the reconnect link for a second after clicking it.
			@set 'hideReconnect', true
			setTimeout (->
				@set 'hideReconnect', false
			), 1000
			model.socket.socket.connect()	# TODO get socket
		reload: ->
			window.location.reload()


