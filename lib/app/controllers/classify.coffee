module.exports = (Ember, App, socket) ->
	_ = require 'underscore'

	App.ClassifyController = Ember.Controller.extend
		needs: ['contact']
		classifyCount: 0
		dynamicQ: null
		flushlist: null
		flushing: false

		thisContact: (->
			unless @get('dynamicQ.length') then return null
			@set 'controllers.contact.content', @get('dynamicQ')?.objectAt(@get 'classifyCount')
		).property 'dynamicQ.@each', 'classifyCount'

		total: (->
			@get('dynamicQ.length') - @get('classifyCount')
		).property 'classifyCount', 'dynamicQ.@each'

		complete: (->
			return @get('classifyCount') is @get('dynamicQ.length')
		).property 'classifyCount', 'dynamicQ@.each'

		continueText: (->
			if not @get 'thisContact.added'
				return 'Save and Continue'
			'Continue'
		).property 'thisContact'
		#).property 'thisContact.added'

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
			if not @get 'thisContact.addedBy'
				@set 'thisContact.addedBy', App.user
				App.user.incrementProperty 'contactCount'
			@store.createRecord 'classify', 
				saved:require('moment')().toDate()
				user: App.user
				contact: @store.find 'contact', @get 'thisContact.id'
			@_next()

		skip: ->
			@store.createRecord 'classify',
				user: App.user
				contact: @store.find 'contact', @get 'thisContact.id'
			@_next()
		ignore: ->
			@get('controllers.contact').content.remove()
			@_next()
		_next: ->
			@get('controllers.contact').content.save()
			@incrementProperty 'classifyCount'

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

		keepGoing: ->						# now disabled, not in template
			@set 'classifyCount', 0


	App.ClassifyView = Ember.View.extend
		template: require '../../../templates/classify.jade'
		classNames: ['classify']
		classifying:true
		didInsertElement: ->
			@set 'controller.$', @$()
			# handle this event from the chrome extension,
			# which brings us scraped data for adding to the classify contact
			Ember.$(document).on 'classifyExtension', null, (ev, tr)=>
				if (ev = ev?.originalEvent?.detail) and (c = @get 'controller.thisContact')
					@get('controller.controllers.contact').getExtensionData ev
		willDestroyElement: ->
			Ember.$(document).off 'classifyExtension'
