module.exports = (Ember, App, socket) ->
	_ = require 'underscore'

	App.ProfileView = Ember.View.extend
		template: require '../../../templates/profile'
		classNames: ['profile']

	App.ProfileController = Ember.ObjectController.extend
		hasQ: false
		setHasQ: (->
			socket.emit 'classifyQ', App.user.get('id'), (results) =>
				@set 'hasQ', results?.length
		).observes 'id'
		contacts: (->
			Ember.ArrayProxy.createWithMixins App.Pagination,
				content: do =>
					Ember.ArrayProxy.createWithMixins Ember.SortableMixin,
						content: do =>
							App.Contact.filter addedBy: @get('id'), (data) =>
								data.get('addedBy.id') is @get('id') and _.contains data.get('knows').getEach('id'), @get('id')
						sortProperties: ['added']
						sortAscending: false
			).property 'id'
