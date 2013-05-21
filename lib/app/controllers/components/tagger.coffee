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
			if @get 'full'
				socket.emit 'tags.all', category: @get('category'), (allTags) =>
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
				@get('tags').find (tag)-> tag.get('body') is candidate.body
			tags.sort()
		_popularTags: (->
			result = []
			if @get 'full'
				socket.emit 'tags.popular', category: @get('category'), (popularTags) =>
					if p = @get('prioritytags')
						popularTags = _.reject popularTags, (t)-> _.contains p.getEach('body'), t.body
					result.pushObjects popularTags
				if (p = @get 'prioritytags') and p.get 'length'
					result.pushObjects p.map (p)-> {body:p.get('body'), category:p.get('category')}
			result
		).property 'prioritytags.@each'
		prioritytags: (->
			if @get 'full'
				query = category: @get('category'), contact: $exists: false
				result = App.Tag.filter query, (data) =>
					if (category = @get('category')) and (category isnt data.get('category'))
						return false
					not data.get('contact')
				options = sortProperties: ['date'], sortAscending: false, content: result, limit: 20
				Ember.ArrayProxy.createWithMixins Ember.SortableMixin, options
			else []
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
					category: @get('category')
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
					if tag and tag.deleteRecord then tag.deleteRecord()	# if its a real tag that exists
					App.store.commit()
				, 1000
			didInsertElement: ->
				@$().addClass(@get('parentView.category') or @get('context.category'))
				if @get 'parentView.animate'
					@set 'parentView.animate', false
					@$().addClass 'animated bounceIn'

		newTagView: App.NewTagView.extend()

		cloudView: Ember.View.extend
			tagName: 'span'
			use: ->
				@get('parentView')._add @get('context.body')
