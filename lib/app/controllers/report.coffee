module.exports = (Ember, App, socket) ->

	App.ReportController = Ember.Controller.extend()

	App.ReportView = Ember.View.extend
		template: require '../../../templates/report'
		# classNames: ['report']
