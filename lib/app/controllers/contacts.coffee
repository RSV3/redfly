module.exports = (Ember, App, socket) ->

	App.ContactsController = Ember.ArrayController.extend App.Pagination,
		content: []

	App.ContactsView = Ember.View.extend
		template: require '../../../views/templates/contacts'
		classNames: ['contacts']
