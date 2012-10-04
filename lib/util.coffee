_ = require 'underscore'
_s = require 'underscore.string'


exports.trim = (string, characters...) ->
	if (string is null) or (string is undefined)
		return string
	if _.isEmpty characters
		return _s.trim string
	result = string
	for item in characters
		result = _s.trim result, item
	result


exports.nickname = (name, email) ->
	_ = require 'underscore'
	if name
		if _s.contains name, ' '
			return name[...name.indexOf(' ')]
		return name
	if email
		return _.first email.split('@')
	null
