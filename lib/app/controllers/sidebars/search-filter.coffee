module.exports = (Ember, App, socket) ->
	_ = require 'underscore'

	App.SearchFilterView = Ember.View.extend
		template: require '../../../templates/sidebars/search-filter'
		classNames: ['search-filter']
		didInsertElement: ->
			$f = $('.search-filter')
			#$f.animate {marginLeft: '-'+$f.width()+'px'}
