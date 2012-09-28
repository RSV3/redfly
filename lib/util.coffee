# TO-DO
validators = {}
validators.isEmail = (email) ->
	_s = require 'underscore.string'
	_s.contains email, '@'


exports.nickname = (name) ->
	_ = require 'underscore'
	_s = require 'underscore.string'	
	if validators.isEmail name
		_.first name.split('@')
	else if _s.contains name, ' '
		name[...name.indexOf(' ')]
	else
		name


_s = require 'underscore.string'

exports.trim = (string) ->
	if not string
		return null
	_s.trim string