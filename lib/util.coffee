# TO-DO
validators = {}
validators.isEmail = (email) ->
	_s = require 'underscore.string'
	_s.contains email, '@'


exports.nickname = (name) ->
	_s = require 'underscore.string'	
	if validators.isEmail name
		name.split('@')[0]
	else if _s.contains name, ' '
		name[...name.indexOf(' ')]
	else
		name
