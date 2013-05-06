module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../../util'

	App.TagAdminView = Ember.View.extend
		template: require '../../../../templates/components/tagadmin'
		classNames: ['tagadmin']
		organization: (->
			@get('parentView.controller.category') isnt 'industry'
		).property 'category'
		category: (->
			@get 'parentView.controller.category'
		).property 'parentView.controller.category' 
		prioritytags: (->
			query = category: @get('category'), contact: $exists: false
			result = App.Tag.filter query, (data) =>
				if (category = @get('category')) and (category isnt data.get('category'))
					return false
				not data.get('contact')
			options = sortProperties: ['date'], sortAscending: false, content: result, limit: 20
			Ember.ArrayProxy.createWithMixins Ember.SortableMixin, options
		).property 'category'
		alltags: (->
			result = Ember.ArrayController.create()
			if c = @get('parentView.controller.category')
				socket.emit 'tags.all', category: c, (allTags) =>
					allTags = _.difference allTags, @get('prioritytags').getEach 'body'
					result.set 'content', _.map allTags, (t)->{body:t}
			result
		).property 'prioritytags.@each'

		click: ->
			$(@get('newTagViewInstance.element')).focus()
		add: ->
			if tag = util.trim @get('currentTag')
				@_add tag
			@set 'currentTag', null
		_add: (tag) ->
			existingTag = @get('prioritytags.content').find (candidate) ->
				tag is candidate.body
			if not existingTag
				t = App.Tag.createRecord
					date: new Date
					category: @get('category')
					body: tag
				App.store.commit()
				@set 'animate', true
			else
				# TODO do this better    @get('childViews').objectAt(0).get('context')      existingTag/@$().addClass 'animated pulse'
				@$(".body:contains('#{tag}')").parent().addClass 'animated pulse'

		tagView: App.TagView.extend
			add: ->
				tag = @get 'context'
				@$().addClass 'animated rotateOutDownLeft'
				newtag = App.Tag.createRecord
					date: new Date
					category: @get 'parentView.category'
					body: tag.body
				App.store.commit()
				@set 'parentView.animate', true
			delete: ->
				tag = @get 'context'
				@$().addClass 'animated rotateOutDownLeft'
				setTimeout =>
					if tag.deleteRecord 		# priority tags are real tags
						tag.deleteRecord()
						App.store.commit()
					else						# the 'alltags' list are just {body:} objs.
												# we need to tell the server to remove any tags with the same name
						if c = @get('parentView.controller.category')
							console.log c
							console.log tag
							socket.emit 'tags.remove', {category: c, body: tag.body}, (removedTags) =>
								console.log "admin removed tags: "
								console.dir removedTags

				, 1000
			didInsertElement: ->
				if @get 'parentView.animate'
					@set 'parentView.animate', false
					@$().addClass 'animated bounceIn'

		newTagView: Ember.TextField.extend
			currentTagBinding: 'parentView.currentTag'
			currentTagChanged: (->
				if tag = @get('currentTag')
					@set 'currentTag', tag.toLowerCase()
			).observes 'currentTag'
			keyDown: (event) ->
				###
				if event.which is 8	# A backspace/delete.
					if not @get('currentTag')
						lastTag = @get 'parentView.prioritytags.lastObject'
						lastTag.deleteRecord()
						App.store.commit()
				# TO-DO was there a reason is sepearted tab complete into a keyDown and keyUp part? Can I do them both on keyDown?
				###
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

