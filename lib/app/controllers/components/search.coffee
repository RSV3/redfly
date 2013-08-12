module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'
	util = require '../../util'


	App.SearchView = Ember.View.extend
		template: require '../../../../templates/components/search'
		classNames: ['search', 'dropdown']
		didInsertElement: ->
			$(@$('[rel=popover]')).popover()
			$(@$()).parent().addClass 'open'	# Containing element needs to have the 'open' class for arrow keys to work
		attributeBindings: ['role']
		role: 'menu'
		hasResults: (->
				not _.isEmpty @get('results')
			).property 'results'

		showResults: (->
				@get('using') and @get('hasResults')
			).property 'using', 'hasResults'
		keyUp: (event) ->
			if event.which is 13	# Enter.
				@set 'using', false
			if event.which is 27	# Escape.
				@$(':focus').blur()
		submit: ->
			@$(':focus').blur()
			@doSearch()
			return false   # Prevent a form submit.

		doSearch: ->
			t = util.trim @get('query')
			if not t.length then t = 'contact:0'	# default to entire collection
			newResults = App.Results.create {text: t}
			App.Router.router.transitionTo "results", newResults

		focusIn: ->
			@set 'using', true
		focusOut: ->
			# Determine the newly focused element and see if it's anywhere inside the search view. 
			# If not, hide the results (after a small delay in case of mousedown).
			setTimeout =>
				focused = $(document.activeElement)
				if not _.first @$().has(focused)
					@set 'using', false
			, 150

		searchBoxView: Ember.TextField.extend
			classNameBindings: [':search-query', 'noResultsFeedback:no-results']
			noResultsFeedback: (->
					@get('parentView.using') and not @get('parentView.hasResults')
				).property 'parentView.using', 'parentView.hasResults'

			resultsBinding: 'parentView.results'
			allResultsBinding: 'parentView.allResults'
			valueBinding: 'parentView.query'
			valueChanged: (->
					query = util.trim @get('value')
					if not query
						@set 'results', null
					else
						prefix = @get('parentView.prefix')
						if prefix then query = util.trim(prefix)+query
						socket.emit 'search', query: query, moreConditions: @get('parentView.conditions'), (results) =>
							query = util.trim @get('value')
							if results.query is query or results.query is "contact:#{query}"
								@set 'results', {}
								allResults = []
								delete results.query
								for type, ids of results
									if ids and ids.length
										if type is 'tag' or type is 'note' then model = _s.capitalize type
										else model = 'Contact'
										@set 'results.' + type, App.store.findMany(App[model], ids)
										allResults.push model
								@set 'allResults', allResults
				).observes 'value', 'parentView.excludes'

