module.exports = (Ember, App, socket) ->
	_ = require 'underscore'

	Ember.RadioButton = Ember.View.extend
		checked: false,
		classNames: ['ember-radio-button'],
		defaultTemplate: Ember.Handlebars.compile '<label><input type="radio" {{ bindAttr name="view.group" value="option"}} />{{view.title}}</label>'

		change: (ec) -> @set "controller.#{@get 'group'}Op", parseInt @get 'option'
		didInsertElement: ()->
			if @get("controller.#{@get 'group'}Op") is parseInt @get 'option'
				@$().find('input').prop 'checked', true

	App.FilterView = Ember.View.extend
		template: require '../../../../templates/sidebars/filter'
		classNames: ['filter']
		newTag: (e) ->
			cat = if $(e.target).hasClass("industry") then 'industry' else 'org'
			@get('controller').tagToggle cat, $(e.target).val().toLowerCase()
			$(e.target).val('')

	App.FilterToggleView = Ember.View.extend
		tagName: 'i'
		classNames: ["togglecarets"]
		didInsertElement: ()->
			$i = @$()
			$i.click ->
				$(this).toggleClass 'icon-caret-right icon-caret-down'
				$d = $("div.#{$(this).attr 'id'}")
				if ($d.toggleClass 'collapsed').hasClass 'collapsed' then $d.hide() else $d.show()
