module.exports = (Ember, App, socket) ->
	validation = require('../validation') socket
	util = require '../util'

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
		template: require '../../../templates/create'
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
			async = require 'async'
			async.forEach fields, (field, cb) =>
				@get(field + 'FieldInstance')._fire cb
			, =>
				if not (@get('nameFieldInstance.error') or @get('emailFieldInstance.error') or @get('pictureFieldInstance.error'))
					properties =
						emails: @get('email')
						names: @get('name')
						knows: Ember.ArrayProxy.create()
						added: new Date
						addedBy: App.user
					if picture = util.trim @get('picture')
						properties.picture = picture
					contact = App.Contact.createRecord properties
					contact.get('knows').pushObject App.user.get('content')
					App.store.commit()

					@$().addClass 'animated lightSpeedOut'
					contact.on 'didCreate', =>
						@get('controller.target').transitionTo 'contact', contact
		reset: ->
			for field in fields
				@set field, null
				@set field + 'FieldInstance.error', null
