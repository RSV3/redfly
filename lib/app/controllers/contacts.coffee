module.exports = (Ember, App, socket) ->


	App.ContactsController = Ember.ArrayController.extend
		sortProperties: ['added']
		sortAscending: false
	
	App.ContactsView = Ember.View.extend
		template: require '../../../views/templates/contacts'
		classNames: ['contacts']
