module.exports = (Ember, DS, App) ->
	_ = require 'underscore'
	util = require './util.coffee'


	# Override this private helper to ensure that ember-data doesn't try to automatically pair up any inverses.
	DS._inverseRelationshipFor = ->

	App.ApplicationAdapter = DS.RESTAdapter.extend
		doOp: (op, type, field, value)->
			new Ember.RSVP.Promise (resolve, reject)->
				success = (json)->
					Ember.run null, resolve, json
				failure = (json)->
					Ember.run null, reject, json
				data = {}
				if field then data[field] = value
				$.ajax
					url: "/db/#{util.typeName type}/#{op}"
					type: if op is 'find' then 'GET' else 'POST'
					data: data
					xhrFields: withCredentials: true
					success: (data, textStatus, xhr)->
						if data then success data
						else failure data
					error: (xhr, textStatus, errorThrown)->
						console.dir textStatus
						failure null
		doFind: (type, field, value)-> @doOp 'find', type, field, value
		find: (store, type, id) -> @doFind type, 'id', id
		findAll: (store, type) -> @doFind type
		findMany: (store, type, ids) -> @doFind type, 'ids', ids
		findQuery: (store, type, query, recordArray) ->
			if query.ids?.length and _.keys(query).length is 1 then	@doFind type, 'ids', query.ids
			else @doFind type, 'query', util.normalizeQuery(query)

		updateRecord: (store, type, record) ->
			rec = record.serialize()
			rec.id = record.get 'id'
			@doOp 'save', type, 'record', rec

		createRecord: (store, type, record) ->
			@doOp 'create', type, 'record', record.serialize()

		deleteRecord: (store, type, record) ->
			@doOp 'remove', type, 'id', record.get('id')
			###
			socket.emit 'db', op: 'remove', type: util.typeName(type), id: record.get('id'), =>
				Ember.run this, ->
					@didSaveRecord store, type, record
			###


	App.ApplicationSerializer = DS.RESTSerializer.extend
		primaryKey: '_id'
		###
		normalize: (type, hash, property)->
			json = id:hash[@primaryKey]
			for prop in hash
				json[prop.camelize()] = hash.get prop
			@_super type, json, property
		###
		addHasMany: (hash, record, key, relationship) ->
			@_super hash, record, key, relationship
			type = record.constructor
			name = relationship.key
			if not @embeddedType type, name
				ids = record.get(name).getEach('id')
				hash[key] = ids


	App.ArrayTransform = DS.Transform.extend
		serialize: (deserialized) ->
			deserialized
		deserialize: (serialized) ->
			serialized
	App.ObjectTransform = DS.Transform.extend
		serialize: (deserialized) ->
			deserialized
		deserialize: (serialized) ->
			serialized
	App.DateTransform = DS.Transform.extend
		serialize: (deserialized) ->
			deserialized
		deserialize: (serialized) ->
			validators = require('validator').validators
			if serialized
				throw new Error 'Invalid date.' if not validators.isDate serialized
				return new Date serialized
	App.StringTransform = DS.Transform.extend
		serialize: (value) -> value
		deserialize: (value) -> value
	App.NumberTransform = DS.Transform.extend
		serialize: (value) -> value
		deserialize: (value) -> value
	App.BooleanTransform = DS.Transform.extend
		serialize: (value) -> value
		deserialize: (value) -> value

	App.Store = DS.Store.extend
		find: (type, id)->
			unless id then return @findAll type
			if Ember.typeOf(id) is 'object' then return @findQuery type, id
			if Ember.typeOf(id) is 'array' then return @findQuery type, ids:id
			@findById type, id+''

