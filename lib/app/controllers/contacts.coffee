module.exports = (Ember, App, socket) ->

	App.ContactsController = Ember.ObjectController.extend
		addedContacts: []
		contacts: (->
			Ember.ArrayProxy.createWithMixins App.Pagination,
				content: do =>
					Ember.ArrayProxy.createWithMixins Ember.SortableMixin,
						content: do => @get 'addedContacts'
						sortProperties: ['added']
						sortAscending: false
		).property 'addedContacts'

	App.ContactsView = Ember.View.extend
		template: require '../../../templates/contacts'
		classNames: ['contacts']
