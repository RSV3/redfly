module.exports = (Ember, App) ->
	_ = require 'underscore'
	socketemit = require '../socketemit.coffee'

	App.ProfileView = Ember.View.extend
		template: require '../../../templates/profile.jade'
		classNames: ['profile']

	App.ProfileController = Ember.ObjectController.extend
		hasQ: false
		setHasQ: (->
			socketemit.get 'classifyQ', App.user.get('id'), (results) =>
				console.log "#{results?.length} to classify"
				@set 'hasQ', results?.length
		).observes 'id'
		contacts: (->
			store = @store
			id = @get 'id'
			Ember.ArrayProxy.createWithMixins App.Pagination,
				content: do ->
					Ember.ArrayProxy.createWithMixins Ember.SortableMixin,
						content: do ->
							store.filter 'contact', {addedBy: id, knows: id}, (data)->
								data.get('knows').then (ids)->
									ids = ids.getEach('id')
									data.get('addedBy')?.get('id') is id and _.contains(ids, id)
						sortProperties: ['added']
						sortAscending: false
				itemsPerPage: 25
			).property 'id'


