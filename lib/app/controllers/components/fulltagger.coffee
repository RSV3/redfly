module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../../util'

	App.FullTaggerView = App.TaggerView.extend
		template: require '../../../../templates/components/tagger'
		classNames: ['tagger']
		gpView: (->
			gpV = this.get('parentView')?.get('parentView')
			if gpV and _.contains(gpV.classNames, 'results') then return gpV
			null
		)
		tags: (->
			sort = field: 'date'
			query = contact: @get('contact.id'), category: @get('category')
			App.filter App.Tag, sort, query, (data) =>
				if (category = @get('category')) and (category isnt data.get('category'))
					return false
				data.get('contact.id') is @get('contact.id')
		).property 'contact.id', 'category'

		storeAutoTags: null
		autoTags: (->
			if (aTags = @get('storeAutoTags')) then return aTags
			if (tags = @get('tags'))
				bodies = tags.getEach 'body'
				socket.emit 'tags.all', category: @get('category'), (allTags) =>
					aTags = @get 'storeAutoTags'
					aTags.pushObjects _.difference allTags, bodies
			@set 'storeAutoTags', []
			@get 'storeAutoTags'
		).property 'cloudTags.@each'	# depends on tags.@each, but let's wait until cloudTags are done.

		cloudTags: (->
			if (bodies = @get('tags')?.getEach('body')) and (popular = @get('_popularTags'))
				popular.reject (i)-> _.contains bodies, i.body
		).property '_popularTags.@each'

		storePriorTags: null
		_priorityTags: (->
			if (pTags = @get('storePriorTags')) then return pTags
			cat = @get 'category'
			if grandparent = @gpView()?.get('storePriorTags')
				if not grandparent[cat] then grandparent[cat] = App.Tag.find category: cat, contact: null
				@set 'storePriorTags', grandparent[cat]
			else @set 'storePriorTags', App.Tag.find category: cat, contact: null
			@get 'storePriorTags'
		).property 'tags.@each'

		storePopTags: null
		_popularTags: (->
			if (pTags = @get('storePopTags')) then return pTags
			cat = @get 'category'
			catid = @get 'catid'
			unless (priorTags = @get('storePriorTags')) and priorTags.get('length')
				return null
			if grandparent = @gpView()?.get('storePopTags')
				if grandparent[cat]
					@set 'storePopTags', grandparent[cat]
					return @get 'storePopTags'
			socket.emit 'tags.popular', category: @get('category'), (popularTags) =>
				pTags = @get 'storePopTags'
				priorTags = @get 'storePriorTags'
				pTags.pushObjects priorTags.map (p)->
					{body:p.get('body'), category:cat, catid:catid}
				priorBodies = priorTags.getEach 'body'
				pTags.pushObjects _.reject(popularTags, (t)-> _.contains priorBodies, t.body)[0...20-priorBodies.length].map (p)->
					{body:p.body, category:cat, catid:catid}

				if grandparent then grandparent[cat] = @get 'storePopTags'
			@set 'storePopTags', []
			@get 'storePopTags'
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
				@$().addClass(@get('parentView.catid') or @get('context.catid'))
				if @get 'parentView.animate'
					@set 'parentView.animate', false
					@$().addClass 'animated bounceIn'

		cloudView: Ember.View.extend
			tagName: 'span'
			use: ->
				@get('parentView')._add @get('context.body')
