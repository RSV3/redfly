module.exports = (DS, App, schemas) ->
	_ = require 'underscore'
	Types = require('../schemas.coffee').Types


	baseModelProperties =
		typeName: (->
				util = require './util.coffee'
				util.typeName this
			).property()
	BaseModel = DS.Model.extend App.Validatable, baseModelProperties
	BaseModel.reopenClass baseModelProperties


	for schema in schemas.all()
		properties = {}
		for pathName, path of schema.definition
			isArray = _.isArray path
			if isArray
				path = path[0]
				schemas[schema.name].definition[pathName] =
					type: Array
					element: path
			if _.isFunction path
				# Shorthand schema path definition, just 'String', 'Date', etc.
				throw new Error 'Specify the type key.'
			properties[pathName] = do ->
				if isArray
					if ref = path.ref
						return DS.hasMany ref.toLowerCase(), {async:true}
					return DS.attr 'array', defaultValue: []
				if _.isObject(path) and not path.type
					if _.isEmpty
						schemas[schema.name].definition[pathName] = type: Types.Mixed   # Empty object is the same as Mixed.
					# TODO handle nested definitions eventually
					return DS.attr 'object'
				switch path.type
					when String then DS.attr 'string'
					when Date then DS.attr 'date'
					when Boolean then DS.attr 'boolean'
					when Number then DS.attr 'number'
					when Types.ObjectId then DS.belongsTo path.ref
					when Types.Mixed then DS.attr 'object'
					else
						throw new Error
		baseClass = BaseModel
		if schema.base
			baseClass = App[schema.base]
			_s = require 'underscore.string'
			DS.Adapter.configure 'App.' + schema.name, alias: _s.underscored(schema.name)
			_.extend schema.definition, schemas[schema.base].definition
		model = App[schema.name] = baseClass.extend properties
		model.reopen schema: schema.definition
		model.reopenClass schema: schema.definition
