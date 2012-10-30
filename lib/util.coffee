_ = require 'underscore'
_s = require 'underscore.string'


exports.trim = (string, characters) ->
	if (string is null) or (string is undefined)
		return string
	_s.trim string, characters


exports.nickname = (name, email) ->
	if name
		if _s.contains name, ' '
			return name[...name.indexOf(' ')]
		return name
	if email
		return _.first email.split('@')
