module.exports = (Ember, App, socket) ->

	App.ResponsesController = App.ResultsController.extend
		comments:null
		links:null
		hasResults:false
		dontFilter:false

	App.ResponsesView = App.ResultsView.extend()

