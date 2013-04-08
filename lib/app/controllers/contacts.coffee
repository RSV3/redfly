module.exports = (Ember, App, socket) ->

	App.ContactsController = Ember.ObjectController.extend
		page1Contacts: []
		addedContacts: (->
			oneC = @get 'page1Contacts'
			if oneC and oneC.get 'length'
				App.Contact.find
					conditions:
						added: $exists: true
					options:
						sort: added: -1
			else []
		).property 'page1Contacts.@each'
		contacts: (->
			allC = @get 'addedContacts'
			if allC and allC.get 'length'
				Ember.ArrayProxy.createWithMixins App.Pagination,
					content: do =>
						Ember.ArrayProxy.createWithMixins Ember.SortableMixin,
							content: do => @get 'addedContacts'
							sortProperties: ['added']
							sortAscending: false
			else
				Ember.ArrayProxy.create content: do => @get 'page1Contacts'
		).property 'addedContacts.@each'

	App.ContactsView = Ember.View.extend
		template: require '../../../templates/contacts'
		classNames: ['contacts']
