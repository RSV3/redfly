module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../../util'


	App.TaggerView = Ember.View.extend
		template: require '../../../../views/templates/components/tagger'
		classNames: ['tagger']
		tags: (->
				sort = field: 'date'
				query = contact: @get('contact.id'), category: @get('category')
				App.filter App.Tag, sort, query, (data) =>
					if (category = @get('category')) and (category isnt data.get('category'))
						return false
					data.get('contact.id') is @get('contact.id')
			).property 'contact.id', 'category'
		availableTags: (->
				allTags = @get '_allTags.content'
				dictionaryTags = dictionary[@get('category') or 'redstar']
				available = _.union dictionaryTags, allTags
				available = _.reject available, (candidate) =>
					for tag in @get('tags').mapProperty('body')
						if tag is candidate
							return true
				available.sort()
			).property 'category', 'tags.@each', '_allTags.@each'
		_allTags: (->
				socket.emit 'tags', category: @get('category'), (bodies) ->
					tags.pushObjects bodies
				tags = Ember.ArrayProxy.create content: []
			).property 'category'
		click: ->
			$(@get('newTagViewInstance.element')).focus()
		add: ->
			if tag = util.trim @get('currentTag')
				@_add tag
			@set 'currentTag', null
		_add: (tag) ->
			existingTag = @get('tags').find (candidate) ->
				tag is candidate.get('body')
			if not existingTag
				App.Tag.createRecord
					date: new Date	# Only so that sorting is smooth.
					creator: App.user
					contact: @get 'contact'
					category: @get('category') or 'redstar'
					body: tag
				App.store.commit()
				# TODO hack to make all known tags update when a the user adds a tag without causing flicker in the tag cloud
				# update: I think I can fix this by making the 'tags' property settable
				socket.emit 'tags', category: @get('category'), (bodies) =>
					tags = @get '_allTags'
					tags.clear()
					tags.pushObjects bodies
				@set 'animate', true
			else
				# TODO do this better    @get('childViews').objectAt(0).get('context')      existingTag/@$().addClass 'animated pulse'
				@$(".body:contains('" + tag + "')").parent().addClass 'animated pulse'

		tagView: App.TagView.extend
			delete: (event) ->
				tag = @get 'context'
				$(event.target).parent().addClass 'animated rotateOutDownLeft'
				setTimeout =>
						tag.deleteRecord()
						App.store.commit()
					, 1000
			didInsertElement: ->
				if @get 'parentView.animate'
					@set 'parentView.animate', false
					@$().addClass 'animated bounceIn'
			# TODO do this and 'delete' above, figure out animation framework
			# willDestroyElement: ->
			# 	@$().addClass 'animated rotateOutDownLeft'

		newTagView: Ember.TextField.extend
			currentTagBinding: 'parentView.currentTag'
			currentTagChanged: (->
					if tag = @get('currentTag')
						@set 'currentTag', tag.toLowerCase()
				).observes 'currentTag'
			keyDown: (event) ->
				if event.which is 9	# A tab.
					if @get('currentTag')
						return false	# Prevent focus from changing, the normal tab key behavior, if there's a tag currently being typed.
			keyUp: (event) ->
				if event.which is 8	# A backspace/delete.
					if not @get('currentTag')
						lastTag = @get 'parentView.tags.lastObject'
						lastTag.deleteRecord()
						App.store.commit()
				if event.which is 9
					# Defer adding the tag in case a typeahead selection is highlighted and should be added instead.
					_.defer =>
						@get('parentView').add()
			didInsertElement: ->
				@set 'typeahead', $(@$()).typeahead
					source: null	# Placeholder, populate later.
					items: 6
					updater: (item) =>
						@get('parentView')._add item
						@set 'currentTag', null
						return null
				# Monkey-patch bootstrap so I can trigger bindings. Current way this is happening is by customizing bootstrap.js
				# typeahead = $(@$()).data('typeahead')
				# move = typeahead.move
				# that = this
				# typeahead.move = (e) ->
				# 	move.call this, e
				# 	that.set 'currentTag', that.get('currentTag')
			updateTypeahead: (->
					@get('typeahead').data('typeahead').source = @get('parentView.availableTags')
				).observes 'parentView.availableTags.@each'
			attributeBindings: ['size', 'autocomplete', 'tabindex']
			size: (->
					2 + @get('currentTag.length')
				).property 'currentTag'
			autocomplete: 'off'
			tabindex: (->
					@get('parentView.tabindex') or 0
				).property 'parentView.tabindex'

		# availableTagView: Ember.View.extend
		# 	tagName: 'span'
		# 	use: ->
		# 		tag = @get('context').toString()
		# 		@get('parentView')._add tag
		# TODO
		# renderedAvailableTags: (->
		# 		html = _.reduce @get('availableTags'), (memo, tag) ->
		# 			memo + '<a href="#" {{action use target="view"}}><span class="label"><i class="icon-plus"></i> ' + tag + '</span></a>'
		# 		html.htmlSafe()
		# 	).property 'availableTags.@each'


	dictionary =
		redstar: [
			'ideator'
			'germ'
			'pitch'
			'project'
			'founder'
			'action'
			'healthcare'
			'research'
			'salon'
			'aging'
			'underemployment'
			'loopit'
			'vinely'
			'gosprout'
			'greenback'
			'silver black'
			'atlas'
			'mentor'
			'intern'
			'investor'
			'candidate'
		]
		industry: [
			'legal'
			'attorney'
			'partner'
			'director'
			'venture capital (vc)'
			'private equity (pe)'
			'consumer electronics'
			'medical devices'
			'tv'
			'news'
			'print'
			'music'
			'consumer packaged goods (cpg)'
			'retail'
			'apparel'
			'sports'
			'entertainment'
			'healthcare'
			'research'
			'e-commerce'
			'b2b'
			'b2c'
			'direct sales'
			'finance'
			'banking'
			'small medium business (smb)'
			'big data'
			'social media'
			'consulting'
			'investment banking'
			'angel investing'
			'consumer'
			'web'
			'enterprise'
			'software'
			'academic'
			'professor'
			'media'
		]
