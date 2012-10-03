exports.identity = (identity) ->
	_s = require 'underscore.string'


	# If only the username was typed make it a proper email.
	if not _s.contains identity, '@'
		identity += '@redstar.com'
	return identity
