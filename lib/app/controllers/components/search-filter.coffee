module.exports = (Ember, App, socket) ->
	_ = require 'underscore'

	App.SearchFilterView = Ember.View.extend
		template: require '../../../templates/components/search-filter'
		tagName: 'div'
		classNames: ['search-filter', 'overlay', 'span4']
		didInsertElement: ->
			$f = $('.search-filter')
			$f.animate {marginLeft: '-'+$f.width()+'px'}
