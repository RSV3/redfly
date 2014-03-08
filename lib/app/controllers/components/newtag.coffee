
module.exports = (Ember, App) ->
	_ = require 'underscore'

	App.NewTagView = Ember.TextField.extend
		currentTagBinding: 'parentView.currentTag'
		currentTagChanged: (->
			if tag = @get('currentTag')
				@set 'currentTag', tag.toLowerCase()
		).observes 'currentTag'
		keyDown: (event) ->
			if event.which is 8	# A backspace/delete.
				if not @get('currentTag')
					lastTag = @get 'parentView.tags.lastObject'
					if lastTag and lastTag.deleteRecord
						lastTag.deleteRecord()
						lastTag.save()
			if event.which is 9	# A tab.
				if @get('currentTag')
					return false	# Prevent focus from changing, the normal tab key behavior, if there's a tag currently being typed.
		keyUp: (event) ->
			if event.which is 9
				# Defer adding the tag in case a typeahead selection is highlighted and should be added instead.
				_.defer =>
					@get('parentView').add()
		updateTypeahead: (->
			@get('parentView.autoTags').then (srcs)=>
				unless srcs?.length then return
				typeAheadOpts =
					items: 6
					highlight: true
				updater = (item)=>
					if category = @get('category') then @get('parentView').addTag category, item
					else @get('parentView').addNose item
				theseAutos = new Bloodhound
					datumTokenizer: (d)-> Bloodhound.tokenizers.whitespace d.value
					queryTokenizer: Bloodhound.tokenizers.whitespace
					local: _.map @get('srcs'), (d)-> value:d
				theseAutos.initialize()
				@$().typeahead(typeAheadOpts, theseAutos.ttAdapter()
				).on('typeahead:selected', (ev, data)->
					updater data.value
				)
		).observes 'parentView.autoTags.@each'
		attributeBindings: ['size', 'autocomplete', 'tabindex']
		size: (->
			2 + (@get('currentTag.length') or 0)
		).property 'currentTag'
		autocomplete: 'off'
		tabindex: (->
			@get('parentView.tabindex') or 0
		).property 'parentView.tabindex'

