module.exports = (Ember, App, socket) ->


	App.ClassifyController = Ember.ObjectController.extend
		contentBinding: 'App.router.contactController.content'

		total: (->
				queueLength = App.user.get('queue.length')
				if not App.user.get('classifyMore')
					return Math.min @_baseQueueLength - App.user.get('classifyCount'), queueLength
				queueLength
			).property 'App.user.queue.length', 'App.user.classifyCount', 'App.user.classifyMore'
		complete: (->
				noMore = not @get('content')
				if not App.user.get('classifyMore')
					return noMore or (App.user.get('classifyCount') is @_baseQueueLength)
				noMore
			).property 'content', 'App.user.classifyCount', 'App.user.classifyMore'
		next: (->
				App.user.get 'queue.firstObject'
			).property 'App.user.queue.firstObject'
		_baseQueueLength: 10
		add: ->
			if not @get 'added'
				@set 'added', new Date
				@set 'addedBy', App.user
				App.store.commit()

			socket.emit 'removeQueueItemAndAddExclude', App.user.get('id')
			@_continue()
		skip: ->
			exclude =
				email: @get('email')
			if name = @get('primaryName')
				exclude.name = name
			App.user.get('excludes').pushObject exclude

			socket.emit 'removeQueueItemAndAddExclude', App.user.get('id'), exclude
			@_continue()
		_continue: ->
			App.user.incrementProperty 'classifyCount'
			App.user.get('queue').shiftObject()
			App.store.commit()

			@set 'content', App.user.get('queue.firstObject')
		keepGoing: ->
			App.user.set 'classifyMore', true


	App.ClassifyView = Ember.View.extend
		template: require '../../../views/templates/classify'
		classNames: ['classify']
