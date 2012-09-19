module.exports = (Ember, App) ->
	_ = require 'underscore'
	_s = require 'underscore.string'

	# TO-DO
	# path = require 'path'
	# views = path.dirname(path.dirname(__dirname)) + '/views/templates'
	# views = '../../views/templates'
	# template: require '../../views/templates/application'


	App.ApplicationView = Ember.View.extend
		templateName: 'application'
		didInsertElement: ->
			$('.search-query').addClear top: 6 # TODO It would be nice if this were the scoped jquery object @$ but it weirdly doesn't have plugins.
	App.ApplicationController = Ember.Controller.extend() #recentContacts: App.Contacts.find() @where('added_date').exists(1).sort(['date', 'desc']).limit(3)


	App.HomeView = Ember.View.extend
		templateName: 'home'
		classNames: ['home']
		toggle: ->
			@get('controller').set 'showConnect', true
	App.HomeController = Ember.Controller.extend()

	App.ContactView = Ember.View.extend
		templateName: 'contact'
		classNames: ['contact']
		add: ->
			if note = _s.trim @get('controller.currentNote')
				newNote = App.store.createRecord App.Note,	# TODO will this work as App.Note.createRecord? Change here and elsewhere.
					author: App.user
					contact: @get 'controller.content'
					body: note
				App.store.commit()
				# @get('controller.notes').unshiftObject newNote # TODO XXX
				@set 'controller.currentNote', null
		newNoteView: Ember.TextField.extend
			attributeBindings: ['placeholder', 'rows']
			placeholder: (->
					'Write something noteworthy about ' + @get('controller.firstName') + '. Tell a story, describe a secret talent, whatever!'
				).property 'controller.firstName'
			rows: 3
	App.ContactController = Ember.ObjectController.extend
		currentNote: ''
		notes: (-> App.Note.find contact: @.get('_id'))
			.property()
		tags: (-> App.Tag.find contact: @.get('_id'))
			.property()
		firstName: (->
				name = @get('name')
				# name[...name.indexOf(' ')]	# TODO, breaks router for some reason?
				return name
			).property 'name'
		history: (->
				App.Mail.find(sender: App.user._id, recipient: @get('_id'), sort: 'date', limit: 1)[0]	# TODO does @ here refer to the contactController?
			).property()
		historyCount: (->
				App.Mail.find(sender: App.user._id, recipient: @get('_id')).get('length')	# TODO does @ here refer to the contactController?
			).property()
		canAdd: (-> _s.isBlank(@get('currentNote'))).property 'currentNote'

	App.ProfileView = Ember.View.extend
		templateName: 'profile'
		classNames: ['profile']
	App.ProfileController = Ember.ObjectController.extend
		contacts: (-> App.Contact.find addedBy: @get('_id'))
			.property()
		total: (-> @get('contacts.length'))	# TODO not working
			.property 'contacts' 

	App.TagsView = Ember.View.extend
		templateName: 'tags'
		classNames: ['tags']
	App.TagsController = Ember.ArrayController.extend()

	App.ReportView = Ember.View.extend
		templateName: 'report'
		classNames: ['report']
	App.ReportController = Ember.Controller.extend()


	# TODO XXX
	# - make sure clicking anywhere gives the new tag thing focus
	# - make sure all attrs on newTagView are rendered
	# - does currentTag need to be an ember object to get updated? Prolly not.
	App.TaggerView = Ember.View.extend
		templateName: 'tagger'
		classNames: ['tagger']
		availableTags: ['An example tag', 'Yet another example tag!']	# TODO XXX XXX
		# availableTags: (->
		# 		allTags = App.Tag.find()	# TODO XXX distinct tags
		# 		_.reject allTags, (otherTag) ->
		# 			for tag in @get 'contact.tags'
		# 				tag.body is otherTag.body
		# 	).property 'contact.tags'
		click: (event) ->
			@get('newTagView').$().focus()
		add: (event) ->
			if tag = _s.trim @get('newTagView.currentTag')
				existingTag = _.find @get('contact.tags'), (otherTag) ->
					tag is otherTag
				if not existingTag
					newTag = App.store.createRecord App.Tag,
						creator: App.user
						contact: @get 'contact'
						body: tag
					App.store.commit()
					# @get('content.tags').pushObject newTag # TODO XXX XXX
					# TODO find the element of the tag and: @$().addClass 'animated bounceIn'
				else
					# TODO find the element of the tag and play the appropriate animation
					# probably make it play faster, like a mac system componenet bounce
					# existingTag/@$().addClass 'animated pulse'
				@set 'newTagView.currentTag', null
		tagView: Ember.View.extend
			tagName: 'span'
			remove: ->
				tag = @get 'tag'
				# @parentView.get('contact.tags').removeObject tag # TO-DO unnecessary right? Ember-data will remove the tag from the view?
				@$().addClass 'animated rotateOutDownLeft'
				tag.deleteRecord()
		newTagView: Ember.TextField.extend
			attributeBindings: ['data-source']
			'data-source': (-> @get 'parentView.availableTags').property('parentView.availableTags')
			currentTagChanged: (->
					@$().attr 'size', 1 + @get('currentTag.length') # TODO is input size changing when typeahead preselect gets entered
				).observes 'currentTag'


	App.LoaderView = Ember.View.extend	# TO-DO does this have to be on the App object?
		templateName: 'loader'

		didInsertElement: ->
			@$('#signupMessage').modal()
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
				before_open: (pnotify) ->
					pnotify.css top: '60px'
					@$('#loadingStarted').appendTo '#loading'

			socket.emit 'parse', App.user._id, ->
				@get('loading').effect 'bounce'
				@get('loading').pnotify type: 'success', closer: true
				App.User.find _id: App.user._id	# Classify queue has been determined and saved on the server, refresh by querying the store.
				@get('manager').transitionTo 'done'

			socket.on 'parse.total', (total) ->
				@set 'current', 0
				@set 'total', total
				@get('manager').transitionTo 'started'
			socket.on 'parse.name', ->
				App.User.find _id: App.user._id	# We just figured out the logged-in user's name, refesh by querying the store.
			socket.on 'parse.update', ->
				@incrementProperty 'current'

		manager: Ember.StateManager.create
			start: Ember.State.create()
			parsing: Ember.State.create()
			done: Ember.State.create()

		percent: (->
				current = @get 'current'
				total = @get 'total'
				if not current or not total
					return 0
				Math.round (current / total) * 100
			).property 'current', 'total'

		stateBinding: 'manager.currentState.name'	# TODO will this work?


	# TO-DO define 'connected' and 'canConnect' like derby does.
	App.ConnectionView = Ember.View.extend	# TO-DO probably inline this in appview # TO-DO does this have to be on the App object?
		templateName: 'connection'
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


