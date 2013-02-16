module.exports = (Ember, App, socket) ->

	App.NoteView = Ember.View.extend
		classNames: ['media']
		didInsertElement: ->
			if @get 'controller.animate'
				@set 'controller.animate', false
				@$().addClass 'animated flipInX'

