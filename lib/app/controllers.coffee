module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'

	# TO-DO
	# path = require 'path'
	# views = path.dirname(path.dirname(__dirname)) + '/views/templates'
	# views = '../../views/templates'
	# template: require '../../views/templates/application'


	App.ApplicationView = Ember.View.extend
		template: require '../../views/templates/application'
		didInsertElement: ->
			# TOD addclear
	App.ApplicationController = Ember.Controller.extend #recentContacts: App.Contacts.find() @where('added_date').exists(1).sort(['date', 'desc']).limit(3)
		searchChanged: (->
				search = _s.trim @get('search')
				if not search
					@set 'results', null
				else
					socket.emit 'search', search, (results) =>
						@set 'results', App.Contact.find _id: $in: results
					# TODO
					# @set 'results', App.Contact.find(email: $regex: )
			).observes 'search'


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
	App.ContactController = Ember.ObjectController.extend
		currentNote: ''
		history: (->
				App.Mail.find(
					conditions:
						sender: App.user.get('_id')
						recipient: @get('_id')
					options:
						sort: 'date'
						limit: 1
				)	# TODO replace #eaches and add .objectAt 0
			).property()
		histories: (->
				App.Mail.find
					sender: App.user.get('_id')
					recipient: @get('_id')
			).property()
		historyCount: (->
				@get 'histories.length'
			).property 'histories.@each'
		canAdd: (-> _s.isBlank(@get('currentNote'))).property 'currentNote'	# TO-DO why doesn't this work.
		emptyNotesText: (->
				if Math.random() < 0.6
					# return 'No notes about ' + @get('nickname') + ' yet.'	# TO-DO doesn't work?
					return 'No notes about this contact yet.'
				('...and that\'s why you ' +
					' <a href="http://www.dailymotion.com/video/xrjyfz_that-s-why-you-always-leave-a-note_shortfilms" target="_blank">' +
					 'always leave a note!</a>'
				).htmlSafe()
			).property()
		add: ->
			if note = _s.trim @get('currentNote')
				newNote = App.store.createRecord App.Note,	# TODO will this work as App.Note.createRecord? Change here and elsewhere.
					author: App.user
					contact: @get 'content'
					body: note
				App.store.commit()
				@get('notes').unshiftObject newNote
				@set 'currentNote', ''

		classifying: (->
				window.document.location.href.indexOf('classify') isnt -1
			).property()
		next: ->
			if not @get 'dateAdded'
				@set 'dateAdded', new Date
				@set 'addedBy', App.user
			App.user.set 'classifyIndex', (App.user.get('classifyIndex') or 0) + 1 # TODO

			index = App.user.get 'classifyIndex'
			contact = App.user.get('classify').objectAt index

			@set 'content', contact



	App.ProfileView = Ember.View.extend
		template: require '../../views/templates/profile'
		classNames: ['profile']
	App.ProfileController = Ember.ObjectController.extend
		# contacts: (-> App.Contact.find addedBy: @get('_id'))	# TODO XXX XXX
		contacts: (-> App.Contact.find())
			.property()
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
		click: (event) ->
			# @get('newTagView').$().focus() # TO-DO
			@$('.new-tag').focus()
		add: (event) ->
			if tag = _s.trim @get('newTagView.currentTag')
				existingTag = _.find @get('contact.tags'), (otherTag) =>	# TODO is fat-arrow necessary?
					tag is otherTag
				if not existingTag
					newTag = App.store.createRecord App.Tag,
						creator: App.user
						contact: @get 'contact'
						body: tag
					App.store.commit()
					@get('contact.tags').pushObject newTag
					# TODO find the element of the tag and: @$().addClass 'animated bounceIn'
				else
					# TODO find the element of the tag and play the appropriate animation
					# probably make it play faster, like a mac system componenet bounce. And maybe play a sound.
					# existingTag/@$().addClass 'animated pulse'
				@set 'newTagView.currentTag', ''
		tagView: Ember.View.extend
			tagName: 'span'
			classNames: ['tag']
			delete: (event) ->
				tag = @get 'context'
				$(event.target).parent().addClass 'animated rotateOutDownLeft' # TO-DO icky, why doesn't the scoped jquery work? @$
				setTimeout =>
						@get('parentView.contact.tags').removeObject tag # This would be unnecessary except 'tags' is currently a copy.
					, 1000
				tag.deleteRecord()
				App.store.commit()
		newTagView: Ember.TextField.extend
			classNames: ['new-tag-field']
			currentTag: ''
			currentTagChanged: (->
					console.log '4444'	# TOOD XXX
					@set 'currentTag', tag.toLowerCase()
					@$().attr 'size', 1 + @get('currentTag.length') # TODO is input size changing when typeahead preselect gets entered
				).observes 'currentTag'
			attributeBindings: ['data-source', 'data-provide', 'data-items', 'size', 'autocomplete']
			'data-source': (->
					# allTags = App.Tag.find()	# TODO XXX distinct tags
					# _.reject allTags, (otherTag) ->
					# 	for tag in @get 'parentView.contact.tags'
					# 		tag.body is otherTag.body
					quoted = _.map ['vc', 'mentor', 'physician', 'entrepreneur'], (item) -> '"' + item + '"'
					'[' + quoted + ']'
				).property 'parentView.contact.tags.@each'
			'data-provide': 'typeahead'
			'data-items': 6
			size: 1
			autocomplete: 'off'


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

			socket.emit 'parse', App.user.get('_id'), =>
				@get('loading').effect 'bounce'
				@get('loading').pnotify type: 'success', closer: true
				App.User.find _id: App.user.get('_id')	# Classify queue has been determined and saved on the server, refresh by querying the store.
				@set 'stateDone', true
				@set 'stateParsing', false

			socket.on 'parse.total', (total) =>
				@set 'current', 0
				@set 'total', total
				@set 'stateParsing', true
				@set 'stateConnecting', false
			socket.on 'parse.name', =>
				App.User.find _id: App.user.get('_id')	# We just figured out the logged-in user's name, refesh by querying the store.
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


