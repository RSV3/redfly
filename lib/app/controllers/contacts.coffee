module.exports = (Ember, App, socket) ->

	App.ContactsController = Ember.ArrayController.extend App.Pagination,
		content: Ember.ArrayProxy.create Ember.SortableMixin,
			content: App.Contact.find(added: $exists: true)
			sortProperties: ['added']
			sortAscending: false

	App.ContactsView = Ember.View.extend
		template: require '../../../templates/contacts'
		classNames: ['contacts']
