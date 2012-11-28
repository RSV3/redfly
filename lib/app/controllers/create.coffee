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
		template: require '../../../views/templates/create'
		classNames: ['create']

		nameField: FormField.extend
			_fire: ->
				name = filter.contact.name @get('parentView.name')
				@set 'parentView.name', name
				validate.contact.name name, (message) =>
					@set 'error', message
		emailField: FormField.extend
			_fire: ->
				email = filter.contact.email @get('parentView.email')
				@set 'parentView.email', email
				validate.contact.email email, (message) =>
					@set 'error', message
		pictureField: FormField.extend
			_fire: ->
				picture = filter.contact.picture @get('parentView.picture')
				@set 'parentView.picture', picture
				if picture	# Picture isn't required, only set an error message if the user typed something.
					@set 'error', validate.contact.picture picture

		create: ->
			for field in fields
				@get(field + 'FieldInstance')._fire()
			# TODO bulletproofing: asynchronous validation above might not be done, namely uniqueness checks
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
				# Wait for animation to complete.
				setTimeout ->
						App.get('router').send 'goContact', contact
					, 1000
		reset: ->
			for field in fields
				@set field, null
				@set field + 'FieldInstance.error', null
