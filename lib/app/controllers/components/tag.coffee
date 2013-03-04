module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../../util'


	App.TagView = Ember.View.extend
		template: require '../../../../templates/components/tag'
		tagName: 'span'
		classNames: ['tag']
		search: ->
			newResults = App.Results.create {text: util.trim @get('context.body')}
			@get('controller').transitionTo "results", newResults
			# TODO this doesn't work any more because the router isn't available globally on the router, but I'm not sure anyone knew about this feature anyway
			# searchBox = App.get 'router.applicationView.spotlightSearchViewInstance.searchBoxViewInstance'
			# searchBox.set 'value', 'tag:' + @get('context.body')
			# # Make sure the search field eventually gets focus even if the action triggering search, such as a click, changes it at the moment.
			# _.defer ->
			# 	$(searchBox.get('element')).focus()
