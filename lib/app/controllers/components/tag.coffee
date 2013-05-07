module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../../util'

	App.TagView = Ember.View.extend
		template: require '../../../../templates/components/tag'
		tagName: 'span'
		classNames: ['tag']
		search: ->
			newResults = App.Results.create {text: 'tag:' + util.trim @get('context.body')}
			@get('controller').transitionTo "results", newResults
