module.exports = (Ember, App, socket) ->


	App.ClassifyController = Ember.ObjectController.extend
		contentBinding: 'App.router.contactController.content'

		total: (->
				Math.min App.user.get('queue.length'), maxQueueLength - App.user.get('classifyCount')
			).property 'App.user.queue.length', 'App.user.classifyCount'
		complete: (->
				return @get('noMore') or (App.user.get('classifyCount') is maxQueueLength)
			).property 'noMore', 'App.user.classifyCount'
		noMore: (->
				# content.id and not just content because if you arrive from the router it sets a proxy initially.
				not @get('content.id')
			).property 'content.id'

		add: ->
			contact = @get 'content'
			if not contact.get 'added'
				contact.set 'added', new Date
				contact.set 'addedBy', App.user

			@_continue()
		skip: ->
			exclude = {}
			if email = @get('email')
				exclude.email = email
			if name = @get('name')
				exclude.name = name

			existingExclude = App.user.get('excludes').find (candidate) ->
				(exclude.name is candidate.name) and (exclude.email is candidate.email)
			if not existingExclude
				# TODO hack temporarily, setting the excludes property to a new object is the only way ember-data will pick up that it's been changed.
				excludes = App.user.get('excludes').slice()
				excludes.pushObject exclude
				App.user.set 'excludes', excludes

			@_continue()
		_continue: ->
			App.user.get('queue').shiftObject()
			App.store.commit()
			
			App.user.incrementProperty 'classifyCount'
			@set 'content', App.user.get('queue.firstObject')
		keepGoing: ->
			App.user.set 'classifyCount', 0


	App.ClassifyView = Ember.View.extend
		template: require '../../../views/templates/classify'
		classNames: ['classify']



	maxQueueLength = 7