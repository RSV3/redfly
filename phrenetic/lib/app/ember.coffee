module.exports = (Ember, DS, App) ->
	_ = require 'underscore'
	async = require 'async'
	Types = require('../schemas.coffee').Types


	App.findOne = (type, query = {}) ->
		util = require './util.coffee'
		query = util.normalizeQuery query
		query.options.limit = 1

		# TO-DO remove this old implementation if I never figue out how it was supposed to work: http://progfu.com/post/40016169330/how-to-find-a-model-by-any-attribute-in-ember-js
		# records = type.find query
		# records.one 'didLoad', ->
		# 	records.resolve records.get('firstObject')
		# records
		single = Ember.ObjectProxy.create()
		records = type.find query
		records.one 'didLoad', ->
			single.set 'content', records.get('firstObject')
		single


	App.refresh = (record) ->
		App.store.findQuery record.constructor, record.get('id')


	App.Pagination = Ember.Mixin.create
		rangeStart: 0
		totalBinding: 'content.length'
		itemsPerPage: 10
		paginatedItems: (->
				@get('content').slice @get('rangeStart'), @get('rangeStop')
			).property 'content.@each', 'rangeStart', 'rangeStop'

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

		# Probably need this eventually.
		# page: function() {
		#   return (get(this, 'rangeStart') / get(this, 'rangeWindowSize')) + 1;
		# }.property('rangeStart', 'rangeWindowSize').cacheable(),
		# totalPages: function() {
		#   return Math.ceil(get(this, 'total') / get(this, 'rangeWindowSize'));
		# }.property('total', 'rangeWindowSize').cacheable(),


	App.Validatable = Ember.Mixin.create
		filter: do ->
			filterValue = (value, schema) ->
				if schema.trim
					util = require './util.coffee'
					value = util.trim value
				if schema.lowercase
					value = value.toLowerCase()
				if schema.uppercase
					value = value.toUpperCase()
				if set = schema.set
					value = set value
				value
			(name) ->
				schema = @get 'schema.' + name
				value = @get name
				if not value
					return
				if schema.type is Array
					value = value.map (elementValue) ->
						filterValue elementValue, schema.element
				else
					value = filterValue value, schema
				@set name, value
		validate: do ->
			validators = require('validator').validators
			messages =
				required: 'Dudebro, you have to enter something dude, bro.'
				format: (type) ->
					'Pretty sure that\'s not a ' + type + '.'
				enum: 'That\'s not an acceptable choice.'
				unique: (type) ->
					'That ' + type + ' is in use.'
				min: 'Too low.'
				max: 'Too high.'
			validateValue = (name, value, schema, cb) ->
				if not value and ((not schema.required) or (schema.default))
					# Stop validating if the field isn't set and it's not required / will be populated with a default value later.
					return cb()
				if schema.required and not value
					return cb messages.required
				switch schema.type
					when String
						if not _.isString value
							return cb messages.format 'string'
					when Date
						if not validators.isDate value
							return cb messages.format 'date'
					when Boolean
						if value not in [true, false, 'true', 'false']
							return cb messages.format 'boolean'
					when Number
						if isNaN new Number(value)
							return cb messages.format 'number'
					when Types.ObjectId
						if not (value instanceof DS.Model)
							return cb messages.format 'reference'
					when Types.Mixed then ;
					else
						throw new Error
				if (rule = schema.validate) and not rule(value)
					return cb messages.format name
				if (enumeration = schema.enum) and value not in enumeration
					return cb messages.enum
				if (match = schema.match) and not match.test value
					return cb messages.format name
				if (min = schema.min) and value < min
					return cb messages.min
				if (max = schema.max) and value > max
					return cb messages.max
				# TODO have a route for checking uniqueness, something like this:
				# socket.emit 'verifyUniqueness', field: 'email', value: email, (duplicate) ->
				# 	if duplicate
				# 		return cb messages.unique 'email'
				# 	cb()
				cb()
			(name, cb) ->
				schema = @get 'schema.' + name
				value = @get name
				finish = (message) =>
					# Only the first error message is recorded.
					if not @get 'errors'
						@set 'errors', {}
					# I'd like to use recordWasInvalid here but it doesn't seem to work unless it's after a server response.
					# App.store.recordWasInvalid this, errors
					@set 'errors.' + name, message or null
					cb?()

				# TODO handle nested definitions
				if schema.type is Array
					async.each value, (elementValue, cb) =>
						validateValue 'element', elementValue, schema.element, cb   # TO-DO The name 'element' isn't very helpful to the user.
					, (message) ->
						# async.each expects the first argument to each item callback to be a an error, which if encountered will immediately
						# call the main callback with that error. In our case the first argument is a validation error message so there will be
						# one at most.
						if message
							message = 'Error on item: ' + message
						finish message
				else
					validateValue name, value, schema, finish
		validateAll: (cb) ->
			fields = _.keys @get('schema')
			async.each fields, (field, cb) =>
				@filter field
				@validate field, cb
			, cb
		validateSuccess: (cb) ->
			@validateAll =>
				if not @hasErrors()
					cb()
		hasErrors: ->
			not _.chain(@get('errors'))
				.values()
				.compact()
				.isEmpty()
				.value()


	App.FormData = Ember.Object.extend App.Validatable
