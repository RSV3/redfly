module.exports = (Ember, App, socket) ->

	App.ProfileView = Ember.View.extend
		template: require '../../../templates/profile'
		classNames: ['profile']
			
	App.ProfileController = Ember.ObjectController.extend
		contacts: (->
				Ember.ArrayProxy.create App.Pagination,
					content: do =>
						Ember.ArrayProxy.create Ember.SortableMixin,
							content: do =>
								App.Contact.filter addedBy: @get('id'), (data) =>
									data.get('addedBy.id') is @get('id')
							sortProperties: ['added']
							sortAscending: false
			).property 'id'
