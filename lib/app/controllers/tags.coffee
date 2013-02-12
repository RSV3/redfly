module.exports = (Ember, App, socket) ->

	App.TagsController = Ember.ArrayController.extend App.DeprecatedPaginationMixin,
		content: []

	App.TagsView = Ember.View.extend
		template: require '../../../views/templates/tags'
		classNames: ['tags']
