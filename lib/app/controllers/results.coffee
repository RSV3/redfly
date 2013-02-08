module.exports = (Ember, App, socket) ->

	App.ResultsController = Ember.ArrayController.extend App.Pagination,
		itemController: 'result'
		itemsPerPage: 3
		content: []

	App.ResultsView = Ember.View.extend
		template: require '../../../views/templates/results'

	App.ResultController = Ember.Controller.extend

	App.ResultView = Ember.View.extend App.SomeContactMethods,
		template: require '../../../views/templates/result'
		introView: App.IntroView
		socialView: App.SocialView
		classNames: ['contact']
