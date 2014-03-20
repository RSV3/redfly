module.exports = (Ember, App) ->
	util = require '../../util.coffee'

	App.DashboardController = Ember.ObjectController.extend
		dash:null

	App.DashboardView = Ember.View.extend
		template: require '../../../templates/dashboard.jade'
		classNames: ['dashboard']
		search: (v) ->
			newResults = App.Results.create {text: "company:#{util.trim v}"}
			@get('controller').transitionToRoute "results", newResults
