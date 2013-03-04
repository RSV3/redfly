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
			newResults = App.Results.create {text: util.trim @get('query')}
			@get('controller').transitionTo "results", newResults

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
						socket.emit 'search', query: query, moreConditions: @get('parentView.conditions'), (results) =>
							@set 'results', {}
							allResults = []
							for type, ids of results
								if excludes = @get('parentView.excludes')?.getEach('id')
									ids = _.difference ids, excludes
								if ids.length
									model = 'Contact'
									if type is 'tag' or type is 'note'
										model = _s.capitalize type
									@set 'results.' + type, App[model].find _id: $in: ids
									allResults.push model
							@set 'allResults', allResults
				).observes 'value', 'parentView.excludes'

