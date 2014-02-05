exports.Schema = (name, base, definition) ->
	if arguments.length is 2
		definition = base
		base = undefined
	name: name
	base: base
	definition: definition

Types = {}
for type in ['ObjectId', 'Mixed']
	Types[type] = {}   # Create a different dummy object for each type.
exports.Types = Types

exports.addTimestamp = (schemas) ->
	_ = require 'underscore'
	for schema in schemas
		_.extend schema.definition,
			date: type: Date, required: true, default: Date.now
