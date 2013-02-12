module.exports = (Ember, App, socket) ->

	App.ProfileView = Ember.View.extend
		template: require '../../../views/templates/profile'
		classNames: ['profile']
			
	App.ProfileController = Ember.ObjectController.extend
		contacts: (->
				filtered = App.Contact.filter {addedBy: @get('id')}, (data) =>
					data.get('addedBy.id') is @get('id')
				sorted = Ember.ArrayProxy.create Ember.SortableMixin,
					content: filtered
					sortProperties: ['added']
					sortAscending: false
				Ember.ArrayProxy.create App.Pagination,
					content: sorted
			).property 'id'
