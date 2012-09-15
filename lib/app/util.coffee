exports.identity = (identity) ->
	# validators = require('validator').validators	# TODO 'net' not found?
	validators = {}
	validators.isEmail = (email) ->
		_s = require 'underscore.string'
		_s.contains email, '@'

	# If only the username was typed make it a proper email.
	if not validators.isEmail identity
		identity += '@redstar.com'
	return identity
