module.exports = (Ember, App, socket) ->

	App.ReportController = Ember.Controller.extend()

	App.ReportView = Ember.View.extend
		template: require '../../../views/templates/report'
		# classNames: ['report']
