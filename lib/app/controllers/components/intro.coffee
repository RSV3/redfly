module.exports = (Ember, App) ->

	App.IntroView = Ember.View.extend
		tagName: 'i'
		classNames: ['icon-bullhorn', 'icon-large']
		titleStr: ->
			if ((nick = @get 'controller.addedBy.nickname') and nick.length)
				return "Ask #{nick} for an intro!"
			"Ask for an intro!"
		didInsertElement: ->
			@set 'tooltip', @$().tooltip
				title: @titleStr()
				placement: 'left'
		updateTooltip: (->
			@get('tooltip')?.data('tooltip').options.title = @titleStr()
		).observes 'controller.addedBy.nickname'
		attributeBindings: ['rel']
		rel: 'tooltip'

	App.CatchupView = Ember.View.extend
		tagName: 'i'
		classNames: ['icon-envelope', 'icon-large']
		titleStr: ->
			if ((name = @get('controller.nickname')) and name.length)
				return "Get in touch with #{name} again!"
			'Catchup!'
		didInsertElement: ->
			@set 'tooltip', @$().tooltip
				title: @titleStr()
				placement: 'bottom'
		updateTooltip: (->
			@get('tooltip').data('tooltip').options.title = @titleStr()
		).observes 'controller.nickname'
		attributeBindings: ['rel']
		rel: 'tooltip'

