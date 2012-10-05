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
				# TODO have a check here to wait for contact.isLoaded? See if this getting run before the contact is there actually happens.
				App.Tag.find contact: @get('contact.id'), category: @get('category')
			).property('contact')
		click: (event) ->
			# @get('newTagView').$().focus() # TO-DO, maybe using the view on 'event'?
			@$('.new-tag').focus()
		add: (event) ->
			if tag = util.trim @get('currentTag')
				existingTag = _.find @get('tags'), (otherTag) =>	# TODO is fat-arrow necessary?
					tag is otherTag	# TODO this doesn't work, but this should: tag is otherTag.get('body')
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
					@$().attr 'size', 2 + @get('currentTag.length') # TODO Different characters have different widths, so this isn't super accurate.
				).observes 'currentTag'