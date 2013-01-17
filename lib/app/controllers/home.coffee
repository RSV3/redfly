module.exports = (Ember, App, socket) ->


	App.HomeController = Ember.Controller.extend()

	App.HomeView = Ember.View.extend
		template: require '../../../views/templates/home'
		classNames: ['home']
