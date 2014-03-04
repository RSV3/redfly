module.exports = (Ember, App) ->

	App.ReportController = Ember.Controller.extend()

	App.ReportView = Ember.View.extend
		template: require '../../../templates/report.jade'
		# classNames: ['report']
