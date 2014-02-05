# Note: "Frame" means mongoose schema. I just picked another term so I wouldn't get them confused with my schemas.

require 'mongoose-schema-extend'
_ = require 'underscore'
db = require('./services').getDb()
Types = require('../schemas').Types


exports.frame = (schemas) ->
	Schema = db.Schema

	frames = {}
	for schema in schemas.all()
		create = (definition, options) ->
			new Schema definition, options
		options = {}
		if schema.base
			# create = frames[schema.base].extend
			options.collection = require('mongoose/lib/utils').toCollectionName schema.base
			_.extend schema.definition, schemas[schema.base].definition

		# Overwrite dummy types with mongoose types.
		for pathName, path of schema.definition
			# TODO this won't work for nested stuff
			if _.isArray path
				path = path[0]
			if path.type is Types.ObjectId
				path.type = Schema.Types.ObjectId
			if path.type is Types.Mixed
				path.type = Schema.Types.Mixed

		if schema.definition._type
			options.discriminatorKey = '_type'
		frame = create schema.definition, options
		frame.set 'toJSON', getters: true   # To make 'id' included in json serialization for the data API.
		frames[schema.name] = frame
		if schema.base
			frame.pre 'save', (next) ->
				@_type = @constructor.modelName
				next()
	frames


exports.compile = (frames) ->
	models = {}
	for name, frame of frames
		models[name] = db.model name, frame
	models
