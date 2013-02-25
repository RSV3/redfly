module.exports = (Ember, App, socket) ->

	App.IntroView = Ember.View.extend
		tagName: 'i'
		didInsertElement: ->
			@set 'tooltip', $(@$()).tooltip
				title: null	# Placeholder, populate later.
				placement: 'bottom'
			updateTooltip: (->
				@get('tooltip').data('tooltip').options.title = 'Ask ' + @get('controller.addedBy.nickname') + ' for an intro!'
			).observes 'controller.addedBy.nickname'
			attributeBindings: ['rel']
			rel: 'tooltip'
