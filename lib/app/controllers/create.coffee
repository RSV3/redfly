module.exports = (Ember, App, socket) ->


	App.CreateController = Ember.ObjectController.extend()
	
	App.CreateView = Ember.View.extend
		template: require '../../../views/templates/create'
		# classNames: ['create']
