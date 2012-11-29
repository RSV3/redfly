module.exports = (Ember, App, socket) ->

	App.TagsController = Ember.ArrayController.extend
		sortProperties: ['count']
		sortAscending: false

	App.TagsView = Ember.View.extend
		template: require '../../../views/templates/tags'
		classNames: ['tags']
		didInsertElement: ->
			socket.emit 'tagStats', (stats) =>
				for stat in stats
					stat.mostRecent = require('moment')(stat.mostRecent).fromNow()
				@set 'controller.content', stats
