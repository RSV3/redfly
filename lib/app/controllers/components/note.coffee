module.exports = (Ember, App, socket) ->

	App.NoteView = Ember.View.extend
		classNames: ['media']
		naturaldate: (->
			require('moment')(@get('content.date')).fromNow()
		).property 'sent'
		didInsertElement: ->
			if @get 'controller.animate'
				@set 'controller.animate', false
				@$().addClass 'animated flipInX'

