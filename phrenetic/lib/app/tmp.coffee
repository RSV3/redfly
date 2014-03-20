_ = require 'underscore'
util = require './util.coffee'
handle = util.handle
socket = require './socket.coffee'

App.ApplicationAdapter = DS.RESTAdapter.extend
	namespace: 'db'
App.ApplicationSerializer = DS.RESTSerializer.extend
	primaryKey: '_id'

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
# TO-DO Workarounds for JSONSerializer turning undefined into null, remove when ember-data stops doing this.
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
	
