module.exports = (Ember, App, socket) ->
	util = require '../../util'

	App.CompaniesController = Ember.ObjectController.extend
		all:null
		companies: (->
			Ember.ArrayProxy.create
				content: @get 'all'
		).property 'all'


	App.CompaniesView = Ember.View.extend
		template: require '../../../templates/companies'
		classNames: ['companies']
		search: (v) ->
			newResults = App.Results.create {text: "company:#{util.trim v}"}
			@get('controller').transitionToRoute "results", newResults
