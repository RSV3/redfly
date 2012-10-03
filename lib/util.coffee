_s = require 'underscore.string'


exports.trim = (string) ->
	if (string is null) or (string is undefined)
		return string
	_s.trim string

exports.nickname = (name, email) ->
	_ = require 'underscore'
	if name
		if _s.contains name, ' '
			return name[...name.indexOf(' ')]
		return name
	if email
		return _.first email.split('@')
	null
