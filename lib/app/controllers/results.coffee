module.exports = (Ember, App, socket) ->


	App.ResultsController = Ember.ArrayController.extend App.Pagination,
		itemsPerPage: 3
		content: []


	App.ResultsView = Ember.View.extend
		template: require '../../../views/templates/results'
		classNames: ['contact']

