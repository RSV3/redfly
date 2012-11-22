module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'
	util = require '../../../util'


	App.SearchView = Ember.View.extend
		template: require '../../../../views/templates/components/search'
		classNames: ['search', 'dropdown']
		didInsertElement: ->
			$(@$('[rel=popover]')).popover()
			$(@$()).parent().addClass 'open'	# Containing element needs to have the 'open' class for arrow keys to work
		attributeBindings: ['role']
		role: 'menu'
		results: Ember.ObjectProxy.create()
		showResults: (->
				# TODO check the substructure of results to make sure there actually are some.
				@get('usingSearch') and @get('results.content')
			).property 'usingSearch', 'results.content'
		keyUp: (event) ->
			if event.which is 13	# Enter.
				@set 'usingSearch', false
			if event.which is 27	# Escape.
				@$(':focus').blur()
		focusIn: ->
			@set 'usingSearch', true
		focusOut: ->
			# Determine the newly focused element and see if it's anywhere inside the search view. If not, hide the results (after a small delay
			# in case of mousedown).
			setTimeout =>
					focused = $(document.activeElement)
					if not _.first @$().has(focused)
						@set 'usingSearch', false
				, 150

		searchBoxView: Ember.TextField.extend
			resultsBinding: 'parentView.results'
			valueChanged: (->
					query = util.trim @get('value')
					if not query
						@set 'results.content', null
					else
						socket.emit 'search', query, (results) =>
							@set 'results.content', {}
							for type, ids of results
								if excludes = @get('parentView.excludes')?.getEach('id')
									ids = _.difference ids, excludes
								model = 'Contact'
								if type is 'tag' or type is 'note'
									model = _s.capitalize type
								@set 'results.' + type, App[model].find _id: $in: ids
				).observes 'value', 'parentView.excludes'
