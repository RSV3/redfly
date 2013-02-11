module.exports = (Ember, App, socket) ->
	_ = require 'underscore'

	App.SearchFilterView = Ember.View.extend
		template: require '../../../views/templates/components/search-filter'
		tagName: 'div'
		classNames: ['search-filter', 'overlay', 'span4']
		didInsertElement: ->
			$f = $('.search-filter')
			$f.css {opacity:1, marginLeft: '-'+$f.width()+'px'}
			$f.animate {marginLeft:0}, 666
