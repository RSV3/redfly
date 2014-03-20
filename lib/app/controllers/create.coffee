module.exports = (Ember, App) ->
	validation = require '../validation.coffee'
	util = require '../util.coffee'

	validate = validation.validate
	filter = validation.filter


	FormField = Ember.TextField.extend
		focusIn: ->
			@set 'error', null
		focusOut: ->
			@_fire()

	fields = ['name', 'email', 'picture']


	App.CreateController = Ember.Controller.extend()

	App.CreateView = Ember.View.extend
		template: require '../../../templates/create.jade'
		classNames: ['create']

		nameField: FormField.extend
			_fire: (cb) ->
				name = filter.contact.name @get('parentView.name')
				@set 'parentView.name', name
				validate.contact.name name, (message) =>
					@set 'error', message
					cb?()
		emailField: FormField.extend
			_fire: (cb) ->
				email = filter.contact.email @get('parentView.email')
				@set 'parentView.email', email
				validate.contact.email email, (message) =>
					@set 'error', message
					cb?()
		pictureField: FormField.extend
			_fire: (cb) ->
				picture = filter.general.picture @get('parentView.picture')
				@set 'parentView.picture', picture
				if picture	# Picture isn't required, only set an error message if the user typed something.
					@set 'error', validate.general.picture picture
				cb?()

		create: ->
			store = @get('controller').store
			async = require 'async'
			async.forEach fields, (field, cb) =>
				@get(field + 'FieldInstance')._fire cb
			, =>
				if not (@get('nameFieldInstance.error') or @get('emailFieldInstance.error') or @get('pictureFieldInstance.error'))
					# NOTE: I could make this simpler by creating the record first and then just modifying its properties, instead of managing all
					# the properties modeled by each form field independently and then collating them all at the end. Creating a transaction
					# manually would assist with this.
					properties =
						emails: @get('email')
						names: @get('name')
						added: new Date
						addedBy: App.user
					if picture = util.trim @get('picture')
						properties.picture = picture
					store.createRecord('contact', properties).save().then (contact)=>
						@$().addClass 'animated lightSpeedOut'

						@get('controller').transitionToRoute 'contact', contact
		reset: ->
			for field in fields
				@set field, null
				@set field + 'FieldInstance.error', null
