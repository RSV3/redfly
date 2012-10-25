module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../../../util'


	App.TaggerView = Ember.View.extend
		template: require '../../../../views/templates/components/tagger'
		classNames: ['tagger']
		tags: (->
				App.Tag.find contact: @get('contact.id'), category: @get('category')
				App.Tag.filter (data) =>
					category = @get('category') or 'redstar'
					(data.get('contact.id') is @get('contact.id')) and (data.get('category') is category)
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
				category = @get('category') or 'redstar'
				socket.emit 'tags', category, (bodies) ->
					tags.pushObjects bodies
				tags = Ember.ArrayProxy.create content: []
			).property 'category'
		click: ->
			# @get('newTagView').$().focus() # TO-DO, maybe using the view on 'event'?
			@$('.new-tag').focus()
		add: ->
			if tag = util.trim @get('currentTag')
				@_add tag
				@set 'currentTag', null
		_add: (tag) ->
			existingTag = @get('tags').find (candidate) ->
				tag is candidate.get('body')
			if not existingTag
				App.Tag.createRecord
					creator: App.user
					contact: @get 'contact'
					category: @get('category') or 'redstar'
					body: tag
				App.store.commit()
				@set 'animate', true
			else
				# TODO do this better    @get('childViews').objectAt(0).get('context')      existingTag/@$().addClass 'animated pulse'
				@$(".body:contains('" + tag + "')").parent().addClass 'animated pulse'

		tagView: Ember.View.extend
			tagName: 'span'
			classNames: ['tag']
			search: ->
				App.set 'search', 'tag:' + @get('context.body')
				# TODO App.router.get('applicationController.searchView.searchBoxView.$')().focus() and make App.search private while I'm at it.
				$('.search-query').focus()
				return false	# Prevent event propogation so that the search field gets focus and not the tagger.
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
			classNames: ['new-tag-field']
			currentTagBinding: 'parentView.currentTag'
			currentTagChanged: (->
					if tag = @get('currentTag')
						@set 'currentTag', tag.toLowerCase()
				).observes 'currentTag'
			keyDown: (event) ->
				if event.which is 9	# A tab.
					@get('parentView').add()
					return false	# Prevent focus from changing, the normal tab key behavior
			didInsertElement: ->
				$(@$()).typeahead
					source: @get('parentView.availableTags')
					items: 6
					updater: (item) =>
						@get('parentView')._add item
						@set 'currentTag', null
						return null
				# Monkey-patch bootstrap so I can trigger bindings.
				# typeahead = $(@$()).data('typeahead')
				# move = typeahead.move
				# that = this
				# typeahead.move = (e) ->
				# 	move.call this, e
				# 	that.set 'currentTag', that.get('currentTag')
			attributeBindings: ['size', 'autocomplete']
			size: (->
					2 + @get('currentTag.length')
				).property 'currentTag'
			autocomplete: 'off'

		availableTagView: Ember.View.extend
			tagName: 'span'
			use: ->
				tag = @get('context').toString()
				@get('parentView')._add tag


	dictionary =
		redstar: [
			'ideator'
			'germ'
			'phase1'
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
