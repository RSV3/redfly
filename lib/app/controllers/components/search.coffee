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

			valueBinding: 'parentView.query'
			theresults: {}
			fragments: {}
			writeResults: (->
				results = {}
				theresults = @get 'theresults'
				for own key,val of @fragments
					if not val?.length or not theresults[key] then results[key]=null
					else results[key] = theresults[key].map (item, index)-> {contact: item, fragment: val[index]}
				@set 'parentView.results', results
			).observes 'theresults.@each.@each.isLoaded'
			valueChanged: (->
					query = util.trim @get('value')
					if not query
						@set 'results', null
					else
						prefix = @get('parentView.prefix')
						if prefix then query = util.trim(prefix)+query
						socket.emit 'search', query: query, moreConditions: @get('parentView.conditions'), (results)=>
							query = util.trim @get('value')
							if results.query is query or results.query is "contact:#{query}"
								@set 'theresults', {}
								@fragments = {}
								tmpres = {}
								delete results.query
								for type, ids of results
									if ids and ids.length
										tmpres[type] = App.store.findMany(App.Contact, _.pluck ids, '_id')
										@fragments[type] = _.pluck ids, 'fragment'
								@set "theresults", tmpres
				).observes 'value', 'parentView.excludes'

