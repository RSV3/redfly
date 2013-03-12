module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	maxQueueLength = 20

	App.ClassifyController = Ember.Controller.extend
		needs: ['contact']

		# TODO hack. For some reason the new ember-data doesn't let me touch the queue before the user is loaded, so I delay the binding creation
		init: ->
			@_super()
			Ember.run.next this, ->
				Ember.bind this, 'model', 'App.user.queue.firstObject'
		# modelBinding: 'App.user.queue.firstObject'
		modelChanged: (->
				@set 'controllers.contact.content', @get('model')
			).observes 'model'

		classifyCount: 0
		total: (->
				Math.min App.user.get('queue.length'), maxQueueLength - @get('classifyCount')
			).property 'App.user.queue.length', 'classifyCount'
		complete: (->
				return @get('noMore') or (@get('classifyCount') is maxQueueLength)
			).property 'noMore', 'classifyCount'
		noMore: (->
				not @get('model')
			).property 'model'
		continueText: (->
				if not @get 'model.added'
					return 'Save and continue'
				'Continue'
			).property 'model.added'
		continue: ->
			if not @get 'model.added'
				@set 'model.added', new Date
				@set 'model.addedBy', App.user
			App.user.get('queue').shiftObject()
			@incrementProperty 'classifyCount'
			@_next()
		skip: ->
			queue = App.user.get 'queue'
			contact = queue.shiftObject()
			queue.pushObject contact
			@_next()
		ignore: ->
			exclude = {user: App.user}
			if email = @get('model.email')
				exclude.email = email
			if name = @get('model.name')
				exclude.name = name
			App.Exclude.createRecord exclude
			App.store.commit()
			knows = @get('model.knows').filter (u)-> u.get('id') isnt App.user.get('id')
			@set 'model.knows.content', knows
			App.user.get('queue').shiftObject()
			@incrementProperty 'classifyCount'
			@_next()
		_next: ->
			App.store.commit()
		keepGoing: ->
			@set 'classifyCount', 0


	App.ClassifyView = Ember.View.extend
		template: require '../../../templates/classify'
		classNames: ['classify']
