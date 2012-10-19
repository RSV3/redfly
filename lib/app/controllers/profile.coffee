module.exports = (Ember, App, socket) ->


	App.ProfileView = Ember.View.extend
		template: require '../../../views/templates/profile'
		classNames: ['profile']
		didInsertElement: ->
			@set 'controller.contacts', App.Contact.find addedBy: @get('controller.id')
			
	App.ProfileController = Ember.ObjectController.extend()
