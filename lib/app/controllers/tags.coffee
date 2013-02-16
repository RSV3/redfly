module.exports = (Ember, App, socket) ->

	App.TagsController = Ember.ArrayController.extend App.Pagination,
		content: (->
			Ember.ArrayProxy.create Ember.SortableMixin,
				content: @stats
				sortProperties: ['count']
				sortAscending: false
		).property 'stats'

	App.TagsView = Ember.View.extend
		template: require '../../../templates/tags'
		classNames: ['tags']
