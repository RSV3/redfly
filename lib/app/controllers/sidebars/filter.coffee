module.exports = (Ember, App, socket) ->
	_ = require 'underscore'

	App.FilterView = Ember.View.extend
		template: require '../../../../templates/sidebars/filter'
		classNames: ['filter']

	App.FilterToggleView = Ember.View.extend
		tagName: 'i'
		classNames: ["togglecarets"]
		didInsertElement: ()->
			$i = @$()
			$i.click ->
				$(this).toggleClass 'icon-caret-right icon-caret-down'
				$d = $("div.#{$(this).attr 'id'}")
				if ($d.toggleClass 'collapsed').hasClass 'collapsed' then $d.hide() else $d.show()
