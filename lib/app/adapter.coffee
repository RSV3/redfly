module.exports = (DS, socket) ->
	
	getTypeName = (type) ->
		_ = require 'underscore'
		_.last type.toString().split('.')

	DS.Adapter.create
		find: (store, type, id) ->
			socket.emit 'db', op: 'find', type: getTypeName(type), id: id, (data) ->
				store.load type, id, data

		# findMany: (store, type, ids) ->
		# 	socket.emit 'db', op: 'find', type: getTypeName(type), ids: ids, (data) ->
		# 		store.loadMany type, data

		findQuery: (store, type, query, array) ->
			if not query.conditions and not query.options
				query = conditions: query
			socket.emit 'db', op: 'find', type: getTypeName(type), query: query, (data) ->
				array.load data

		findAll: (store, type) ->
			socket.emit 'db', op: 'find', type: getTypeName(type), (data) ->
				store.loadMany type, data

		createRecord: (store, type, record) ->
			socket.emit 'db', op: 'create', type: getTypeName(type), record: record.toJSON(), (data) ->
				store.didSaveRecord record, data

		# createRecords: (store, type, array) ->
		# 	socket.emit 'db', op: 'create', type: getTypeName(type), record: array.mapProperty('data'), (data) ->
		# 		store.didCreateRecords type, array, data

		updateRecord: (store, type, record) ->
			socket.emit 'db', op: 'save', type: getTypeName(type), record: record.toJSON(includeId: true), (data) ->
				store.didSaveRecord record, data

		# udpateRecords: (store, type, array) ->
		# 	socket.emit 'db', op: 'save', type: getTypeName(type), record: array.mapProperty('data'), (data) ->
		# 		store.didUpdateRecords type, array, data

		deleteRecord: (store, type, record) ->
			socket.emit 'db', op: 'remove', type: getTypeName(type), id: record.get('id'), ->
				store.didSaveRecord record

		# deleteRecords: (store, type, array) ->
		# 	socket.emit 'db', op: 'remove', type: getTypeName(type), ids: model.get('id'), ->
		# 		store.didDeleteRecords array


		serializer: DS.Serializer.create
			addBelongsTo: (hash, record, key, relationship) ->
				hashKey = @._keyForBelongsTo record.constructor, key
				id = record.get key + '.id'
				hash[hashKey] = id

			addHasMany: (hash, record, key, relationship) ->
				hashKey = @._keyForHasMany record.constructor, key
				ids = record.get(key).getEach('id')
				hash[hashKey] = ids
