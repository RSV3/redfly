module.exports = (Ember, App) ->
	_ = require 'underscore'
	socketemit = require '../../socketemit.coffee'

	Ember.RadioButton = Ember.View.extend
		checked: false,
		classNames: ['ember-radio-button'],
		defaultTemplate: Ember.Handlebars.compile '<label><input type="radio" {{ bindAttr name="view.group" value="option"}} />{{view.title}}</label>'

		change: (ec) -> @set "controller.#{@get 'group'}Op", parseInt @get 'option'
		didInsertElement: ()->
			if @get("controller.#{@get 'group'}Op") is parseInt @get 'option'
				@$().find('input').prop 'checked', true


	App.AutoCompleteView = Ember.TextField.extend
		autocompletes: null
		cantMatchTag: false
		didInsertElement: ->
			category = @get('category')
			if category?.length
				if category is 'industry' then conditions = category:'industry'
				else conditions = category:$ne:'industry'
				socketemit.get 'tags.all', conditions, (allTags) =>
					@set 'autocompletes', allTags
			else @get('parentView.controller').store.filter('user', {name:$exists:true}, (u)->u?.get('name')?.length).then (allUsers)=>
				@set 'autocompletes', allUsers.getEach 'name'
		updateTypeahead: (->
			typeAheadOpts =
				items: 6
				autoselect: true
				highlight: true
			updater = (item)=>
				if category = @get('category') then @get('parentView').addTag category, item
				else @get('parentView').addNose item
			theseAutos = new Bloodhound
				datumTokenizer: (d)-> Bloodhound.tokenizers.whitespace d.value
				queryTokenizer: Bloodhound.tokenizers.whitespace
				local: _.map @get('autocompletes'), (d)-> value:d
			theseAutos.initialize()
			@$().typeahead(typeAheadOpts, source: (q, cb)=>
				theseAutos.ttAdapter() q, (a)=>
					if a?.length then @$().removeClass 'error'
					else @$().addClass 'error'
					cb a
			).on('typeahead:selected', (ev, data)->
				updater data.value
			).on('typeahead:autocompleted', (ev, data)->
				updater data.value
			)
		).observes 'autocompletes.@each'


	App.FilterView = Ember.View.extend
		template: require '../../../../templates/sidebars/filter.jade'
		classNames: ['filter']

		nextNewUser: null
		doToggleUser: (->
			if (u = @get 'nextNewUser')
				if u = u.nextObject 0
					@get('controller').userToggle u.get('id'), u.get('name')
		).observes 'nextNewUser.@each'
		addNose: (name)->
			@set 'nextNewUser', @get('controller').store.filter 'user', (data)->
				data.get('name') is name

		addTag: (cat, body)->
			if c = @get 'controller'
				c.tagToggle cat, body


	App.FilterToggleView = Ember.View.extend
		tagName: 'i'
		classNames: ["togglecarets"]
		didInsertElement: ()->
			$i = @$()
			$i.click ->
				$(this).toggleClass 'fa-caret-right fa-caret-down'
				$d = $("div.#{$(this).attr 'id'}")
				if ($d.toggleClass 'collapsed').hasClass 'collapsed' then $d.hide() else $d.show()
