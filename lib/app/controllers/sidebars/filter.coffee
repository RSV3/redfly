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


	App.AutoCompleteView = Ember.TextField.extend
		allautos: null
		autocompletes: null
		setACs: (->
			a = @get 'allautos'
			if a?.get('length') and not @get('category')?.length
				@set 'autocompletes', _.reject a.getEach('name'), (n)-> not n?.length
		).observes 'allautos.@each'
		didInsertElement: ->
			category = @get('category')
			@set 'typeahead', $(@$()).typeahead
				source: null	# Placeholder, populate later.
				items: 6
				updater: (item) =>
					if category then @get('parentView').addTag category, item
					else @get('parentView').addNose item
					return null
			if category?.length
				if category is 'industry' then conditions = category:'industry'
				else conditions = category:$ne:'industry'
				socket.emit 'tags.all', conditions, (allTags) =>
                    @set 'autocompletes', allTags
			else @set 'allautos', App.User.filter {}, (i)->true
		updateTypeahead: (->
			if t=@get('typeahead') then t.data('typeahead').source = @get('autocompletes')
		).observes 'autocompletes.@each'


	App.FilterView = Ember.View.extend
		template: require '../../../../templates/sidebars/filter'
		classNames: ['filter']

		nextNewUser: null
		doToggleUser: (->
			if u = @get 'nextNewUser'
				@get('controller').userToggle u.getEach('id')[0], u.getEach('name')[0]
		).observes 'nextNewUser.@each'
		addNose: (name)->
			@set 'nextNewUser', App.User.filter (data) ->
					data.get('name') is name

		addTag: (cat, body)->
			@get('controller').tagToggle cat, body


	App.FilterToggleView = Ember.View.extend
		tagName: 'i'
		classNames: ["togglecarets"]
		didInsertElement: ()->
			$i = @$()
			$i.click ->
				$(this).toggleClass 'icon-caret-right icon-caret-down'
				$d = $("div.#{$(this).attr 'id'}")
				if ($d.toggleClass 'collapsed').hasClass 'collapsed' then $d.hide() else $d.show()
