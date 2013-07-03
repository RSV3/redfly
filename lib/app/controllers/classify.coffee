module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	#maxQueueLength = 20

	App.ClassifyController = Ember.Controller.extend
		needs: ['contact']
		classifyCount: 0
		dynamicQ: null
		flushlist: null
		flushing: false

		thisContact: (->
			@get('dynamicQ')?.objectAt(@get 'classifyCount')
		).property 'dynamicQ', 'classifyCount'

		modelChanged: (->
			if (c = @get 'thisContact')
				@set 'controllers.contact.content', c
				@set 'controllers.contact.forceShowEmail', true
		).observes 'thisContact'

		###
		total: (->
				Math.min App.user.get('queue.length'), maxQueueLength - @get('classifyCount')
			).property 'App.user.queue.length', 'classifyCount'
		complete: (->
				return @get('noMore') or (@get('classifyCount') is maxQueueLength)
			).property 'noMore', 'classifyCount'
		noMore: (->
				not @get('model')
			).property 'model'
		###
		total: (->
			total = @get('dynamicQ.length') - @get('classifyCount')
			App.admin.set 'classifyCount', total
			total
		).property 'classifyCount', 'dynamicQ'

		complete: (->
				return @get('classifyCount') is @get('dynamicQ.length')
			).property 'classifyCount', 'dynamicQ'

		continueText: (->
				if not @get 'thisContact.added'
					return 'Save and Continue'
				'Continue'
			).property 'thisContact.added'
		continue: ->
			tags = @$.find('div.tag-category:first')
			if not tags.find('.tag').length
				tip = $('a.btn-success').tooltip
					title: "Please set at least one tag"
					placement: 'bottom'
					trigger: 'manual'
					delay: { show: 123, hide: 1234 }
				tip.tooltip 'show'
				return Ember.run.later this, ()->
					tip.tooltip 'hide'
				, 2000

			@set 'thisContact.updated', new Date
			@set 'thisContact.updatedBy', App.user
			if not @get 'thisContact.classified'
				@set 'thisContact.classified', new Date
			if not @get 'thisContact.added'
				@set 'thisContact.added', new Date
				@set 'thisContact.addedBy', App.user
			App.Classify.createRecord user:App.user, saved:require('moment')().toDate(), contact:@get('thisContact')
			App.store.commit()
			@incrementProperty 'classifyCount'
			@_next()

		unflush: -> @set 'flushing', false
		flush: ->
			@set 'flushlist', @get('dynamicQ').filter (item, index)=>
				item.set 'checked', true
				index >= @get 'classifyCount'
			@set 'flushing', true
		flushem: ->
			cons = @get('flushlist').filter((item)-> item.get 'checked').getEach('id')
			socket.emit 'flush', cons, -> true	# just gonna assume success ...
			@set 'dynamicQ', @get('flushlist').filter((item)-> not item.get 'checked')
			@set 'flushing', false

		skip: ->
			App.Classify.createRecord user: App.user, contact: @get('thisContact')
			App.store.commit()
			knows = @get('thisContact.knows').filter (u)-> u.get('id') isnt App.user.get('id')
			@set 'thisContact.knows.content', knows
			@incrementProperty 'classifyCount'
			@_next()
		ignore: ->
			App.Exclude.createRecord user: App.user, contact: @get 'thisContact'
			App.store.commit()
			knows = @get('thisContact.knows').filter (u)-> u.get('id') isnt App.user.get('id')
			@set 'thisContact.knows.content', knows
			@incrementProperty 'classifyCount'
			@_next()
		_next: ->
			App.store.commit()
		keepGoing: ->						# now disabled, not in template
			@set 'classifyCount', 0


	App.ClassifyView = Ember.View.extend
		template: require '../../../templates/classify'
		classNames: ['classify']
		didInsertElement: ->
			@set 'controller.$', @$()
		classifying:true
