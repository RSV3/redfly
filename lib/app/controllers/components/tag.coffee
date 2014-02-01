module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../../util.coffee'

	App.TagView = Ember.View.extend
		template: require '../../../../templates/components/tag.jade'
		tagName: 'span'
		classNames: ['tag']
		search: ->
			newResults = App.Results.create {text: 'tag:' + util.trim @get('context.body')}
			@get('controller').transitionToRoute "results", newResults
