module.exports = (Ember, App, socket) ->


	App.ClassifyController = Ember.ObjectController.extend
		contentBinding: 'App.router.contactController.content'

		currentClassify: (->
				App.user.get('classifyIndex') + 1
			).property 'App.user.classifyIndex'
		next: ->
			if not @get 'added'
				@set 'added', new Date
				@set 'addedBy', App.user
				App.store.commit()

			index = App.user.incrementProperty 'classifyIndex'
			App.store.commit()

			contact = App.user.get('classifyQueue').objectAt index
			@set 'content', contact


	App.ClassifyView = Ember.View.extend
		template: require '../../../views/templates/classify'
		classNames: ['classify']
