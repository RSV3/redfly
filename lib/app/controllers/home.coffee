module.exports = (Ember, App, socket) ->


	App.HomeController = Ember.Controller.extend()

	App.HomeView = Ember.View.extend
		template: require '../../../templates/home'
		classNames: ['home']
