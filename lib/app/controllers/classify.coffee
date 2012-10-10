module.exports = (Ember, App, socket) ->


	App.ClassifyController = Ember.ObjectController.extend
		contentBinding: 'App.router.contactController.content'

		currentClassify: (->
				App.user.get('classifyIndex') + 1
			).property 'App.user.classifyIndex'
		add: ->
			if not @get 'added'
				@set 'added', new Date
				@set 'addedBy', App.user
				App.store.commit()

			index = App.user.incrementProperty 'classifyIndex'
			App.store.commit()

			@_next index
		skip: ->
			exclude =
				email: @get('email')
			if name = @get('primaryName')
				exclude.name = name
			App.user.get('excludes').pushObject exclude

			index = App.user.get 'classifyIndex'
			App.user.get('classifyQueue').removeAt index
			socket.emit 'removeQueueItemAndAddExclude', App.user.get('id'), index, exclude

			App.store.commit()

			@_next index
		_next: (index) ->
			contact = App.user.get('classifyQueue').objectAt index
			@set 'content', contact


	App.ClassifyView = Ember.View.extend
		template: require '../../../views/templates/classify'
		classNames: ['classify']
