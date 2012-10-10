module.exports = (Ember, App, socket) ->


	App.ProfileView = Ember.View.extend
		template: require '../../../views/templates/profile'
		classNames: ['profile']
			
	App.ProfileController = Ember.ObjectController.extend
		contacts: (-> App.Contact.find 'addedBy': @get('id'))
			.property 'content'
		total: (-> @get('contacts.length'))
			.property 'contacts.@each'
