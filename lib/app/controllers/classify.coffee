module.exports = (Ember, App, socket) ->


	App.ClassifyController = Ember.ObjectController.extend
		contentBinding: 'App.router.contactController.content'

		total: (->
				Math.min App.user.get('queue.length'), maxQueueLength - App.user.get('classifyCount')
			).property 'App.user.queue.length', 'App.user.classifyCount'
		complete: (->
				noMore = not @get('content')
				return noMore or (App.user.get('classifyCount') is maxQueueLength)
			).property 'content', 'App.user.classifyCount'
		next: (->
				App.user.get 'queue.firstObject'
			).property 'App.user.queue.firstObject'

		add: ->
			contact = App.user.get('queue').shiftObject()
			if not contact.get 'added'
				contact.set 'added', new Date
				contact.set 'addedBy', App.user

			socket.emit 'removeQueueItemAndAddExclude', App.user.get('id')
			@_continue()
		skip: ->
			# TODO hack
			asdf = App.user.get('queue').shiftObject()
			asdf.set 'addedBy', undefined
			exclude =
				email: @get('email')
			if name = @get('primaryName')
				exclude.name = name
			App.user.get('excludes').pushObject exclude

			socket.emit 'removeQueueItemAndAddExclude', App.user.get('id'), exclude
			@_continue()
		_continue: ->
			App.user.incrementProperty 'classifyCount'
			
			App.store.commit()
			@set 'content', App.user.get('queue.firstObject')
		keepGoing: ->
			App.user.set 'classifyCount', 0


	App.ClassifyView = Ember.View.extend
		template: require '../../../views/templates/classify'
		classNames: ['classify']



	maxQueueLength = 10