module.exports = (Ember, App) ->
	_ = require 'underscore'
	_s = require 'underscore.string'
	util = require '../../util.coffee'
	socketemit = require '../../socketemit.coffee'


	App.SearchView = Ember.View.extend
		template: require '../../../../templates/components/search.jade'
		classNames: ['search', 'dropdown']
		didInsertElement: ->
			$(@$('[rel=popover]')).popover()
			$(@$()).parent().addClass 'open'	# Containing element needs to have the 'open' class for arrow keys to work
		attributeBindings: ['role']
		role: 'menu'
		results: {}
		hasResults: (->
			not _.isEmpty @get('results')
		).property 'results'

		showResults: (->
			@get('using') and @get('hasResults')
		).property 'using', 'hasResults'
		click: (event)->
			@set 'using', true
		keyUp: (event) ->
			if event.which is 13	# Enter.
				@set 'using', false
			else if event.which is 27	# Escape.
				@$(':focus').blur()
			else @set 'using', true
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
		focusOut: (ev)->
			@set 'using', false
			# Determine the newly focused element and see if it's anywhere inside the search view.
			# If not, hide the results (after a small delay in case of mousedown).
			setTimeout =>
				if @get 'using' then @set 'using', false
			, 123

		searchBoxView: Ember.TextField.extend
			classNameBindings: [':search-query', 'noResultsFeedback:no-results']
			noResultsFeedback: (->
				@get('parentView.using') and not @get('parentView.hasResults')
			).property 'parentView.using', 'parentView.hasResults'

			valueBinding: 'parentView.query'
			theresults: {}
			fragments: {}
			valueChanged: (->
				store= @get('parentView.controller').store
				@set 'parentView.using', true
				@set 'theresults', {}
				@set 'fragments',  {}
				if not (query = util.trim @get('value')) then return @set 'results', null
				if prefix = @get('parentView.prefix') then query = util.trim(prefix)+query
				socketemit.get 'search', {query: query, moreConditions: @get('parentView.conditions')}, (results)=>
					query = util.trim @get('value')
					if results.query is query or results.query is "contact:#{query}"
						delete results.query
						xcludes = @get 'parentView.excludes'
						@set 'parentView.results', {}
						for type, ids of results
							do (type, ids)=>
								if ids and ids.length
									if xcludes and xcludes.length
										ids = _.reject ids, (o)-> _.contains xcludes, o._id
									if ids.length
										frags = _.pluck ids, 'fragment'
										store.find('contact', _.pluck ids, '_id').then (list)=>
											if list?.get 'length'
												pVresults = @get 'parentView.results'
												# easiest way to update the box is to rebuild it
												newpVr = {}
												for own k,v of pVresults
													newpVr[k] = v
												newpVr[type] = list.map (item, index)->
													contact: item
													fragment: frags[index]
												@set 'parentView.results', newpVr
			).observes 'value', 'parentView.excludes'

