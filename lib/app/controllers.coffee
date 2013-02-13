module.exports = (Ember, App, socket) ->

	# This is stupid. Just instantiate directly, this wrapper adds no value.
	App.filter = (type, sort, query, filter) ->
		records = type.filter query, filter
		sort.asc ?= true
		options =
			content: records
			sortProperties: [sort.field]
			sortAscending: sort.asc
		Ember.ArrayProxy.create Ember.SortableMixin, options
	# TO-DO get rid of this
	App.DeprecatedPaginationMixin = Ember.Mixin.create
		rangeStart: 0
		totalBinding: 'fullContent.length'
		itemsPerPage: 10
		rangeStop: (->
				Math.min @get('rangeStart') + @get('itemsPerPage'), @get('total')
			).property 'total', 'rangeStart', 'itemsPerPage'

		hasPrevious: (->
				@get('rangeStart') > 0
			).property 'rangeStart'
		hasNext: (->
				@get('rangeStop') < @get('total')
			).property 'rangeStop', 'total'
		previousPage: ->
			@decrementProperty 'rangeStart', @get('itemsPerPage')
		nextPage: ->
			@incrementProperty 'rangeStart', @get('itemsPerPage')
		pageChanged: (->
				content = @get('fullContent').slice @get('rangeStart'), @get('rangeStop')
				@replace 0, @get('length'), content
			).observes 'total', 'rangeStart', 'rangeStop'
	

	require('./controllers/components/connection')(Ember, App, socket)
	require('./controllers/components/search')(Ember, App, socket)
	require('./controllers/components/tag')(Ember, App, socket)
	require('./controllers/components/tagger')(Ember, App, socket)
	require('./controllers/components/loader')(Ember, App, socket)
	require('./controllers/components/linker')(Ember, App, socket)
	require('./controllers/components/edit-picture')(Ember, App, socket)

	require('./controllers/application')(Ember, App, socket)
	require('./controllers/home')(Ember, App, socket)
	require('./controllers/profile')(Ember, App, socket)
	require('./controllers/contact')(Ember, App, socket)
	require('./controllers/leaderboard')(Ember, App, socket)
	require('./controllers/contacts')(Ember, App, socket)
	require('./controllers/tags')(Ember, App, socket)
	require('./controllers/report')(Ember, App, socket)
	require('./controllers/create')(Ember, App, socket)
	require('./controllers/classify')(Ember, App, socket)
	require('./controllers/import')(Ember, App, socket)
