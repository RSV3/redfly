module.exports = (Ember, App) ->
	App.ResponsesController = App.ResultsController.extend
		comments: (->
			if @get 'dontFilter' then return @get 'storeComments'
			a = @get 'all'
			if not a?.get 'length' then return null
			@get 'storeComments'
		).property 'all.@each', 'dontFilter'
		links: (->
			if @get 'dontFilter' then return @get 'storeLinks'
			a = @get 'all'
			if not a?.get 'length' then return null
			@get 'storeLinks'
		).property 'all.@each', 'dontFilter'
		storeComments:null
		storeLinks:null
		hasResults:false
		dontFilter:false

	App.ResponsesView = App.ResultsView.extend()

