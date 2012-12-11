module.exports = (Ember, App, socket) ->


	App.ImportController = Ember.Controller.extend()
	
	App.ImportView = Ember.View.extend
		template: require '../../../views/templates/import'
		# classNames: ['import']
