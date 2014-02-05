module.exports = (Ember, App, socket) ->
	_ = require 'underscore'

	App.ProfileView = Ember.View.extend
		template: require '../../../templates/profile.jade'
		classNames: ['profile']

	App.ProfileController = Ember.ObjectController.extend
		hasQ: false
		setHasQ: (->
			socket.emit 'classifyQ', App.user.get('id'), (results) =>
				@set 'hasQ', results?.length
		).observes 'id'
		contacts: (->
			store = @store
			id = @get 'id'
			Ember.ArrayProxy.createWithMixins App.Pagination,
				content: do ->
					Ember.ArrayProxy.createWithMixins Ember.SortableMixin,
						content: do ->
							store.filter 'contact', addedBy: id, (data) =>
								ids = data.get('knows')?.getEach('id')
								data.get('addedBy')?.get('id') is id and _.contains(ids, id)
						sortProperties: ['added']
						sortAscending: false
				itemsPerPage: 25
			).property 'id'
