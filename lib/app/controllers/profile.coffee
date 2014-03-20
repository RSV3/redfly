module.exports = (Ember, App) ->
	_ = require 'underscore'
	socketemit = require '../socketemit.coffee'

	App.ProfileView = Ember.View.extend
		template: require '../../../templates/profile.jade'
		classNames: ['profile']

	App.ProfileController = Ember.ObjectController.extend
		hasQ: false
		setHasQ: (->
			@setupContacts @get 'id'
			socketemit.get "classifyQ/#{App.user.get('id')}", (results) =>
				@set 'hasQ', results?.length
		).observes 'id'
		contacts: []
		setupContacts: (id)->
			@set 'contacts', []
			unless id then return
			@store.filter('contact', {addedBy: id, knows: id}, (data)->
				data.get('addedBy')?.get('id') is id
			).then (chosen)=>
				@set 'contacts', Ember.ArrayProxy.createWithMixins App.Pagination,
					content: do ->
						Ember.ArrayProxy.createWithMixins Ember.SortableMixin,
							content: chosen
							sortProperties: ['added']
							sortAscending: false
					itemsPerPage: 25


