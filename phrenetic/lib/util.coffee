_s = require 'underscore.string'


exports.baseUrl = 'http://' + process.env.HOST

# Underscore.string trim dies when given a falsy string.
exports.trim = (string, characters) ->
	if (string is null) or (string is undefined)
		return string
	_s.trim string, characters

# Dasherizing from camelcase leaves a preceding dash if the first letter is uppercase.
exports.dasherize = (string) ->
	exports.trim(_s.dasherize(string), '-')
