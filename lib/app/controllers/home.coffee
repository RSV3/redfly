module.exports = (Ember, App) ->
	socketemit = require '../socketemit.coffee'

	App.IndexController = Ember.Controller.extend
		andCounting: 0

	App.IndexView = Ember.View.extend
		template: require '../../../templates/home.jade'
		classNames: ['home']
		didInsertElement: ()->
			@$('.carousel').carousel interval: 5000
