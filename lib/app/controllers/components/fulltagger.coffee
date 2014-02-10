module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../../util.coffee'

	App.FullTaggerView = App.TaggerView.extend
		template: require '../../../../templates/components/tagger.jade'
		classNames: ['tagger']
		gpView: (->
			gpV = this.get('parentView')?.get('parentView')
			if gpV and _.contains(gpV.classNames, 'results') then return gpV
			null
		)
		tags: (->
			#sort = field: 'date'
			query = contact: @get('contact.id'), category: @get('category')
			@get('controller').store.filter 'tag', query, (data) =>
				if (category = @get('category')) and (category isnt data.get('category'))
					return false
				data.get('contact.id') is @get('contact.id')
		).property 'contact.id', 'category'

		storeAutoTags: null
		autoTags: (->
			@get('tags').then (tags)=>
				if (aTags = @get('storeAutoTags')) then return aTags
				bodies = tags.getEach 'body'
				@set 'storeAutoTags', []
				socket.emit 'tags.all', category: @get('category'), (allTags) =>
					aTags = @get 'storeAutoTags'
					aTags.addObjects _.difference allTags, bodies
					console.log "making autotags: leaving #{aTags.get('length')} autotags"
				@get 'storeAutoTags'
		).property 'cTags.@each' 	# depends on tags.@each, but let's wait until cloudTags are done.

		cTags:null
		cloudTags: (->
			@set 'cTags', []
			@get('tags').then (tags)=>
				if (popular = @get '_popularTags') and tags.get('length')
					bodies = tags.getEach 'body'
					popular = popular.reject (i)-> _.contains bodies, i.body
				if popular?.length then @get('cTags').addObjects popular
			@get('cTags')
		).property '_popularTags.@each', 'tags.@each'

		storePriorTags: null
		_priorityTags: (->
			if pTags = @get('storePriorTags') then return pTags
			cat = @get 'category'
			store = @get('controller').store
			grandparent = @gpView()?.get('storePriorTags')
			if grandparent?[cat]
				@set 'storePriorTags', grandparent[cat]
			else
				@set 'storePriorTags', []
				store.find('tag', {category: cat, contact: null}).then (tags)=>
					if grandparent then grandparent[cat] = tags
					@get('storePriorTags').addObjects tags
			@get 'storePriorTags'
		).property 'tags.@each'

		storePopTags: null
		_popularTags: (->
			@get('_priorityTags')
			if pTags = @get 'storePopTags' then return pTags
			cat = @get 'category'
			catid = @get 'catid'
			unless (priorTags = @get('storePriorTags')) and priorTags.get('length')
				return null
			grandparent = @gpView()?.get('storePopTags')
			if grandparent?[cat]
				@set 'storePopTags', grandparent[cat]
			else
				@set 'storePopTags', []
				socket.emit 'tags.popular', category: @get('category'), (popularTags) =>
					pTags = @get 'storePopTags'
					if grandparent then grandparent[cat] = pTags
					priorTags = @get 'storePriorTags'
					pTags.addObjects priorTags.map (p)->
						{body:p.get('body'), category:cat, catid:catid}
					priorBodies = priorTags.getEach 'body'
					pTags.addObjects _.reject(popularTags, (t)-> _.contains priorBodies, t.body)[0...20-priorBodies.length].map (p)->
						{body:p.body, category:cat, catid:catid}
					@get('autoTags')

			@get 'storePopTags'
		).property '_priorityTags.@each', 'storePriorTags.@each'


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
				t = @get('controller').store.createRecord 'tag',
					date: new Date	# Only so that sorting is smooth.
					creator: App.user
					contact: @get 'contact'
					category: @get('category')
					body: tag
				t.save()
				@set 'animate', true
			else
				# TODO do this better    @get('childViews').objectAt(0).get('context')      existingTag/@$().addClass 'animated pulse'
				@$(".body:contains('#{tag}')").parent().addClass 'animated pulse'

		tagView: App.TagView.extend
			delete: ->
				tag = @get 'context'
				@$().addClass 'animated rotateOutDownLeft'
				setTimeout =>
					if tag and tag.deleteRecord
						tag.deleteRecord()	# if its a real tag that exists
						tag.save()
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
