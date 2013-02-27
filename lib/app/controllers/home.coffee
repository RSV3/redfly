module.exports = (Ember, App, socket) ->


	App.IndexController = Ember.Controller.extend()

	App.IndexView = Ember.View.extend
		template: require '../../../templates/home'
		classNames: ['home']
