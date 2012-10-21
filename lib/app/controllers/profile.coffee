module.exports = (Ember, App, socket) ->


	App.ProfileView = Ember.View.extend
		template: require '../../../views/templates/profile'
		classNames: ['profile']
			
	App.ProfileController = Ember.ObjectController.extend
		contacts: (->
				App.Contact.find addedBy: @get('id')
				# conditions:
				# 	addedBy: @get('id')
				# options:
				# 	sort: date: -1
				App.Contact.filter (data) =>
					data.get('addedBy') is @get('id')
			).property 'id'
