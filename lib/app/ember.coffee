module.exports = (Ember, App) ->

	App.refresh = (record) ->
		App.store.findQuery record.constructor, record.get('id')

	App.filter = (type, sort, query, filter) ->
		records = type.filter query, filter
		sort.asc ?= true
		options =
			content: records
			sortProperties: [sort.field]
			sortAscending: sort.asc
		Ember.ArrayProxy.create Ember.SortableMixin, options

	App.Pagination = Ember.Mixin.create
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
			).property 'rangeStop', 'itemsPerPage'

		previousPage: ->
			@decrementProperty 'rangeStart', @get('itemsPerPage')
		nextPage: ->
			@incrementProperty 'rangeStart', @get('itemsPerPage')

		# prolly need this eventually
		# page: function() {
		#   return (get(this, 'rangeStart') / get(this, 'rangeWindowSize')) + 1;
		# }.property('rangeStart', 'rangeWindowSize').cacheable(),
		# totalPages: function() {
		#   return Math.ceil(get(this, 'total') / get(this, 'rangeWindowSize'));
		# }.property('total', 'rangeWindowSize').cacheable(),

		pageChanged: (->
				content = @get('fullContent').slice @get('rangeStart'), @get('rangeStop')
				@replace 0, @get('length'), content
			).observes 'total', 'rangeStart', 'rangeStop'
