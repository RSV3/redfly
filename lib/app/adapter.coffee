module.exports = (DS, socket) ->
	
	getTypeName = (type) ->
		_ = require 'underscore'
		_.last type.toString().split('.')

	DS.Adapter.create
		find: (store, type, id) ->
			socket.emit 'db', op: 'find', type: getTypeName(type), id: id, (data) ->
				store.load type, id, data

		findMany: (store, type, ids) ->
			socket.emit 'db', op: 'find', type: getTypeName(type), ids: ids, (data) ->
				store.load type, ids, data

		findQuery: (store, type, query, array) ->
			# TODO 
			console.log 'asdf'
			console.log type
			console.log query
			if not query.conditions
				query = conditions: query
			socket.emit 'db', op: 'find', type: getTypeName(type), query: query, (data) ->
				array.load data

		findAll: (store, type) ->
			socket.emit 'db', op: 'find', type: getTypeName(type), (data) ->
				store.loadMany type, data

		createRecord: (store, type, model) ->
			# TO-DO figure out what 'unsavedData' etc are for
			socket.emit 'db', op: 'create', type: getTypeName(type), record: model.get('data').record, (data) ->
				store.didCreateRecord model, data

		# createRecords: (store, type, array) ->
		# 	socket.emit 'db', op: 'create', type: getTypeName(type), record: array.mapProperty('data'), (data) ->
		# 		store.didCreateRecords type, array, data

		updateRecord: (store, type, model) ->
			# TODO XXX
			# TO-DO figure out what model.get(data) looks like
			# throw new Error 'untested'
			socket.emit 'db', op: 'save', type: getTypeName(type), record: model.get('data').record, (data) ->
				store.didUpdateRecord model, data

		# udpateRecords: (store, type, array) ->
		# 	socket.emit 'db', op: 'save', type: getTypeName(type), record: array.mapProperty('data'), (data) ->
		# 		store.didUpdateRecords type, array, data

		deleteRecord: (store, type, model) ->
			socket.emit 'db', op: 'remove', type: getTypeName(type), id: model.get('id'), ->
				store.didDeleteRecord model

		# deleteRecords: (store, type, array) ->
		# 	socket.emit 'db', op: 'remove', type: getTypeName(type), ids: model.get('_id'), ->
		# 		store.didDeleteRecords array
				