module.exports = (Ember, App, socket) ->

	App.ResultsController = Ember.Controller.extend()

	App.ResultsView = Ember.View.extend
		template: require '../../../views/templates/results'
		# classNames: ['results']

		didInsertElement: ->
			searchBox = App.get 'router.applicationView.spotlightSearchViewInstance.searchBoxViewInstance'
			console.log searchBox.get 'results'
