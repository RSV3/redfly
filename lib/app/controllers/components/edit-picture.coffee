module.exports = (Ember, App, socket) ->
	validation = require('../validation') socket

	validate = validation.validate
	filter = validation.filter


	App.EditPictureView = Ember.View.extend
		template: require '../../../views/templates/components/edit-picture'
		tagName: 'span'
		classNames: ['edit', 'overlay']
		newPicture: ((key, value) ->
				if arguments.length is 1
					return @get 'picture'
				value
			).property 'picture'
		toggle: ->
			@toggleProperty 'show'
		save: ->
			@set 'working', true

			newPicture = filter.general.picture @get('newPicture')
			@set 'newPicture', newPicture
			error = validate.general.picture newPicture
			@set 'error', error
			if not error
				@set 'picture', newPicture
				App.store.commit()
				@toggle()

			@set 'working', false
