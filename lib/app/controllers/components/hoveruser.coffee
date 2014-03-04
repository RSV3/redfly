module.exports = (Ember, App) ->

	App.HoveruserView = Ember.View.extend
		expanded: false
		classNames: ['hoveruser']
		hoverOff: (old)->
			unless old and old.get 'expanded' then return
			$target = old.$().find('.expandthis')
			$target.removeClass('flipcardin').addClass('animated flipcardout')
			Ember.run.later this, =>
				$target.removeClass('flipcard flipcardout flipcardin animated')
				old.set 'expanded', false
			, 1001
		hoverNo: ->
			if old = @get 'parentView.hovering'
				@set 'parentView.hovering', null
				@hoverOff old
			false
		hoverGo: (_this)=>
			if (old = @get 'parentView.hovering') is @ then return false
			if old then @hoverOff old
			@set 'parentView.hovering', @
			Ember.run.later this, =>
				if @ isnt @get 'parentView.hovering' then return false
				@set 'expanded', true
				Ember.run.next this, =>
					if @ isnt @get 'parentView.hovering' then return false
					$target = @$().find('.expandthis')
					$target.addClass('flipcard')
					$target.removeClass('flipcard').addClass('animated flipcardin')
					Ember.run.later this, =>
						$target.removeClass('flipcardin')
						if $target.hasClass('flipcardout') then @hoverOff this
						else $target.removeClass('animated')
					, 1001
			, 234
			false
		mouseLeave: (ev)->
			@hoverNo()
		didInsertElement: ->
			@$().find('a.hoverme').mouseenter =>
				@hoverGo @
