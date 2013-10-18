module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../../util'

	App.FullTaggerView = App.TaggerView.extend
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

		autoTags: (->
			if (bodies = @get('tags')?.getEach('body'))
				socket.emit 'tags.all', category: @get('category'), (allTags) =>
					result.pushObjects _.difference allTags, bodies
			result = []
		).property 'tags.@each'

		cloudTags: (->
			if (bodies = @get('tags')?.getEach('body')) and (popular = @get('_popularTags'))
				popular.reject (i)-> _.contains bodies, i.body
		).property '_popularTags.@each', 'tags.@each'

		_priorityTags: (->
			App.Tag.find category: @get('category'), contact: null
		).property 'category'

		_popularTags: (->
			if (priorTags = @get('_priorityTags')) then priorTags = priorTags.get('length')
			if not priorTags then return null
			socket.emit 'tags.popular', category: @get('category'), (popularTags) =>
				priorTags = @get('_priorityTags')
				result.pushObjects priorTags.map (p)-> {body:p.get('body'), category:p.get('category')}
				priorTags = priorTags.getEach 'body'
				result.pushObjects _.reject popularTags, (t)-> _.contains priorTags, t.body
			result = []
		).property '_priorityTags.@each'


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
					creator: App.User.find App.user.get 'id'
					contact: App.Contact.find @get 'contact.id'
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

		cloudView: Ember.View.extend
			tagName: 'span'
			use: ->
				@get('parentView')._add @get('context.body')
