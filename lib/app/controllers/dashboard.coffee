module.exports = (Ember, App, socket) ->
	util = require '../../util'

	App.DashboardController = Ember.ObjectController.extend
		dash:null

	App.DashboardView = Ember.View.extend
		template: require '../../../templates/dashboard'
		classNames: ['dashboard']
		search: (v) ->
			newResults = App.Results.create {text: "company:#{util.trim v}"}
			@get('controller').transitionToRoute "results", newResults
