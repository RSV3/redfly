module.exports = (Ember, App, socket) ->


	App.ProfileView = Ember.View.extend
		template: require '../../../views/templates/profile'
		classNames: ['profile']
			
	App.ProfileController = Ember.ObjectController.extend
		contacts: (->
				App.filter App.Contact, {field: 'added', asc: false}, {addedBy: @get('id')}, (data) =>
					data.get('addedBy.id') is @get('id')
			).property 'id'
		latestContacts: (->
				@get('contacts').slice 0, 20
			).property 'contacts.@each'
