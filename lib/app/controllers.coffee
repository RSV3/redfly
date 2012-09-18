module.exports = (Ember, App) ->
	_ = require 'underscore'
	_s = require 'underscore.string'

	# path = require 'path'
	# views = path.dirname(path.dirname(__dirname)) + '/views/templates'
	# views = '../../views/templates'
	# template: require '../../views/templates/application'


	App.ApplicationView = Ember.View.extend
		templateName: 'application'
		didInsertElement: ->
			# TODO maybe do this without css selector if possible
			@$('.search-query').addClear top: 6
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
	App.ContactController = Ember.ObjectController.extend
		notes: App.Note.find(author: @_id)
		tags: App.Tag.find(creator: @_id)
		firstName: (->
				name = @get('name')
				name[...name.indexOf(' ')]
			).property 'name'
		history: Ember.Object.create
			content: App.Mail.find(sender: App.user._id, recipient: @_id, sort: 'date', limit: 1)[0]	# TODO does @ here refer to the contactController?
			count: App.Mail.find(sender: App.user._id, recipient: @_id).length	# TODO does @ here refer to the contactController?
		add: ->
			if note = _s.trim @get('currentNote')
				newNote = App.store.createRecord App.Note,	# TODO will this work as App.Note.createRecord? Change here and elsewhere.
					author: App.user	# TODO this probably won't work, try .get 'content'
					body: note
				App.store.commit()
				@get('controller.notes').unshiftObject newTag
				@set 'currentNote', null
		canAdd: (-> not _s.isBlank @get('currentNote')).property 'currentNote'

	App.ProfileView = Ember.View.extend
		templateName: 'profile'
		classNames: ['profile']
	App.ProfileController = Ember.ObjectController.extend
		contacts: (-> App.Contact.find addedBy: @_id)	# TODO XXX why is this a computed property, it doesn't change in response to anything on cont.
			.property()
		total: (-> @get('contacts').get 'length')	# TODO not working
			.property 'contacts' 

	App.TagsView = Ember.View.extend
		templateName: 'tags'
		classNames: ['tags']
	App.TagsController = Ember.ArrayController.extend()

	App.ReportView = Ember.View.extend
		templateName: 'report'
		classNames: ['report']
	App.ReportController = Ember.Controller.extend()


	# TODO
	# - make sure clicking anywhere gives the new tag thing focus
	# - make sure all attrs on newTagView are rendered
	# - does currentTag need to be an ember object to get updated? Prolly not.
	App.TaggerView = Ember.View.extend
		templateName: 'tagger'
		classNames: ['tagger']
		click: (event) ->
			@$().focus()	# TODO this is wrong, get newTagView and focus on it
		add: (event) ->
			if tag = _s.trim @newTagView.get('currentTag')
				existingTag = _.find @get('controller'), (otherTag) ->	# TODO controller.content?
					tag is otherTag
				if not existingTag
					newTag = App.store.createRecord App.Tag,
						creator: App.user	# TODO this probably won't work, try .get 'content'
						body: tag
					App.store.commit()
					@get('controller').pushObject newTag
					# TODO find the element of the tag and: $().addClass 'animated bounceIn'
				else
					# TODO find the element of the tag and play the appropriate animation
					# probably make it play faster, like a mac system componenet bounce
					# existingTag.$().addClass 'animated pulse'
				@newTagView.set 'currentTag', null
		tagView: Ember.View.extend
			tagName: 'span'
			remove: ->
				tag = @get 'content'
				@parentView.get('controller').removeObject tag
				$().addClass 'animated rotateOutDownLeft'
		newTagView: Ember.TextField.extend
			attributeBindings: ['data-source']
			data-source: @get('controller').get 'availableTags'
			change: (event) ->
				event.target.attr 'size', 1 + @currentTag.length	# TODO is input size changing when typeahead preselect gets entered
	App.TaggerController = Ember.ArrayController.extend
		availableTags: ['An example tag', 'Yet another example tag!']	# TODO
		availableTags: (->
				allTags = App.Tag.find()	# TODO XXX distinct tags
				_.reject allTags, (otherTag) ->
					for tag in @get('content')
						tag.body is otherTag.body
			).property 'content'


	App.LoaderView = Ember.View.extend
		templateName: 'loader'

		didInsertElement: ->
			@$('#signupMessage').modal()

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

		loading: $.pnotify
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
				$('#loadingStarted').appendTo '#loading'

		percent: (->
				current = @get 'current'
				total = @get 'total'
				if not current or not total
					return 0
				Math.round (current / total) * 100
			).property 'current', 'total'

		stateBinding: @get 'manager.currentState.name'	# TODO will this work?


	# TODO define 'connected' and 'canConnect' like derby does.
	App.ConnectionView = Ember.View.extend	# TODO probably inline this in appview
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


