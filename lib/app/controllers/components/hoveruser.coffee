module.exports = (Ember, App, socket) ->

	App.HoveruserView = Ember.View.extend
		expanded: false
		classNames: ['hoveruser']
		hoverNo: ->
			if old = @get 'parentView.hovering'
				old.set 'expanded', false
				@set 'parentView.hovering', null
			false
		hoverpro: (_this)=>
			if old = @get 'parentView.hovering'
				old.set 'expanded', false
			if old is @ then @set 'parentView.hovering', null
			else
				@set 'parentView.hovering', @
				Ember.run.later this, =>
					if @ is @get 'parentView.hovering' then @set 'expanded', true
				, 234
			false
		mouseLeave: (ev)->
			@hoverNo()
		didInsertElement: ->
			@$().find('a.hoverme').mouseenter =>
				@hoverpro @
