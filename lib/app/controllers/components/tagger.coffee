module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../../util'


	App.TaggerView = Ember.View.extend
		template: require '../../../../templates/components/tagger'
		classNames: ['tagger']
		tags: (->
				sort = field: 'date'
				query = contact: @get('contact.id'), category: @get('category')
				App.filter App.Tag, sort, query, (data) =>
					if (category = @get('category')) and (category isnt data.get('category'))
						return false
					data.get('contact.id') is @get('contact.id')
			).property 'contact.id', 'category'
		autocompleteTags: (->
				socket.emit 'tags.all', category: @get('category'), (allTags) =>
					allTags = _.union allTags, dictionary[@get('category') or 'organisation']
					allTags = @_filterTags allTags
					result.pushObjects allTags
				result = []
			).property 'category', 'tags.@each', '_popularTags.@each'
		cloudTags: (->
				@_filterTags @get('_popularTags')
			).property 'category', 'tags.@each', '_popularTags.@each'
		_filterTags: (tags) ->
				if not @get('tags')	# Not really sure why this ever comes up blank.
					return []
				tags = _.reject tags, (candidate) =>
					for tag in @get('tags').mapProperty('body')
						if tag is candidate
							return true
				tags.sort()
		_popularTags: (->
				socket.emit 'tags.popular', category: @get('category'), (popularTags) =>
					result.pushObjects popularTags
				result = []
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
					category: @get('category') or 'organisation'
					body: tag
				App.store.commit()
				@set 'animate', true
			else
				# TODO do this better    @get('childViews').objectAt(0).get('context')      existingTag/@$().addClass 'animated pulse'
				@$(".body:contains('#{tag}')").parent().addClass 'animated pulse'

		tagView: App.TagView.extend
			delete: ->
				tag = @get 'context'
				@$().addClass 'animated rotateOutDownLeft'
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
			
			# didInsertElement: ->
			# 	@set 'tooltip', $(@$()).tooltip
			# 		title: null	# Placeholder, populate later.
			# 		placement: 'top'
			# updateTooltip: (->
			# 		@get('tooltip').data('tooltip').options.title = 'Created by ' + @get('creator.canonicalName') + ' ' + require('moment')(@get('date')).fromNow()
			# 	).observes 'creator.canonicalName', 'date'
			# attributeBindings: ['rel']
			# rel: 'tooltip'


		newTagView: Ember.TextField.extend
			currentTagBinding: 'parentView.currentTag'
			currentTagChanged: (->
					if tag = @get('currentTag')
						@set 'currentTag', tag.toLowerCase()
				).observes 'currentTag'
			keyDown: (event) ->
				if event.which is 8	# A backspace/delete.
					if not @get('currentTag')
						lastTag = @get 'parentView.tags.lastObject'
						lastTag.deleteRecord()
						App.store.commit()
				# TO-DO was there a reason is sepearted tab complete into a keyDown and keyUp part? Can I do them both on keyDown?
				if event.which is 9	# A tab.
					if @get('currentTag')
						return false	# Prevent focus from changing, the normal tab key behavior, if there's a tag currently being typed.
			keyUp: (event) ->
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
					@get('typeahead').data('typeahead').source = @get('parentView.autocompleteTags')
				).observes 'parentView.autocompleteTags.@each'
			attributeBindings: ['size', 'autocomplete', 'tabindex']
			size: (->
					2 + (@get('currentTag.length') or 0)
				).property 'currentTag'
			autocomplete: 'off'
			tabindex: (->
					@get('parentView.tabindex') or 0
				).property 'parentView.tabindex'

		cloudTagView: Ember.View.extend
			tagName: 'span'
			use: ->
				tag = @get('content').toString()
				@get('parentView.parentView')._add tag
		# TO-DO remove eventually if not used
		# renderedAvailableTags: (->
		# 		html = _.reduce @get('availableTags'), (memo, tag) ->
		# 			memo + '<a href="#" {{action use target="view"}}><span class="label"><i class="icon-plus"></i> ' + tag + '</span></a>'
		# 		html.htmlSafe()
		# 	).property 'availableTags.@each'


	dictionary =
		organisation: [
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
