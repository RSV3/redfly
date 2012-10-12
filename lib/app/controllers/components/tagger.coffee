module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../../../util'


	App.TaggerView = Ember.View.extend
		template: require '../../../../views/templates/components/tagger'
		classNames: ['tagger']
		tags: (->
				mutable = []
				@get('_rawTags').forEach (tag) ->
					mutable.push tag
				mutable
			).property '_rawTags.@each'
		_rawTags: (->
				App.Tag.find contact: @get('contact.id'), category: @get('category')
			).property 'contact.id', 'category'
		click: ->
			# @get('newTagView').$().focus() # TO-DO, maybe using the view on 'event'?
			@$('.new-tag').focus()
		add: ->
			if tag = util.trim @get('currentTag')
				existingTag = _.find @get('tags'), (candidate) =>
					tag is candidate	# TODO this doesn't work, but this should: tag is candidate.get('body'). Might need fat-arrow above.
				if not existingTag
					newTag = App.store.createRecord App.Tag,
						creator: App.user
						contact: @get 'contact'
						category: @get('category') or 'industry'
						body: tag
					App.store.commit()
					@set 'animate', true
					@get('tags').pushObject newTag
				else
					# TODO find the element of the tag and play the appropriate animation
					# probably make it play faster, like a mac system componenet bounce. And maybe play a sound.
					# existingTag/@$().addClass 'animated pulse'
				@set 'currentTag', null

		tagView: Ember.View.extend
			tagName: 'span'
			classNames: ['tag']
			search: ->
				App.set 'search', 'tag:' + @get('context.body')
				$('.search-query').focus()
				# TODO ideally handle this in TaggerView.click
				return false	# Prevent event propogation so that the search field gets focus and not the tagger.
			delete: (event) ->
				tag = @get 'context'
				$(event.target).parent().addClass 'animated rotateOutDownLeft' # TO-DO icky, why doesn't the scoped jquery work? @$
				setTimeout =>
						@get('parentView.tags').removeObject tag # Timing for animation. This would be unnecessary except 'tags' is currently a copy.
					, 1000
				tag.deleteRecord()
				App.store.commit()
			didInsertElement: ->
				if @get 'parentView.animate'
					@set 'parentView.animate', false
					@$().addClass 'animated bounceIn'
			willDestroyElement: ->
				# TO-DO do this and change the icky code in 'add': http://stackoverflow.com/questions/9925171/deferring-removal-of-a-view-so-it-can-be-animated
				# @$().addClass 'animated rotateOutDownLeft'

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
					return false	# Prevent focus from changing, the normal tab behavior
			tagsBinding: 'parentView.tags'
			attributeBindings: ['size', 'autocomplete', 'dataSource:data-source', 'dataProvide:data-provide', 'dataItems:data-items']
			size: (->
					2 + @get('currentTag.length') # TODO Different characters have different widths, so this isn't super accurate.
				).property 'currentTag'
			autocomplete: 'off'
			dataSource: (->
					category = @get 'parentView.category'
					# TODO include other tags from api call
					# socket.emit 'tags', category, (bodies) ->
					# _.union(_.values(dictionary)...)
					predefined = @get('parentView').dictionary[category or 'industry']
					predefined = _.reject predefined, (candidate) =>
						for tag in @get 'tags'
							if tag.get('body') is candidate
								return true
						return false

					quoted = _.map predefined, (item) -> '"' + item + '"'
					'[' + quoted + ']'
				).property 'tags.@each'
			dataProvide: 'typeahead'
			dataItems: 6


		dictionary:
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
			]
