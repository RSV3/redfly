module.exports = (Ember, App) ->

	App.TagsController = Ember.ObjectController.extend
		stats: []
		tags: (->
			Ember.ArrayProxy.createWithMixins App.Pagination,
				content: do =>
					Ember.ArrayProxy.createWithMixins Ember.SortableMixin,
						content: do => @get 'stats'
						sortProperties: ['count']
						sortAscending: false
		).property 'stats'

	App.TagsView = Ember.View.extend
		template: require '../../../templates/tags.jade'
		classNames: ['tags']

