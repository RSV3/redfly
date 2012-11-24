exports.identity = (identity) ->
	_s = require 'underscore.string'

	# If only the username was typed make it a proper email.
	if not _s.contains identity, '@'
		identity += '@redstar.com'
	identity


exports.notify = (options) ->
	_ = require 'underscore'

	defaults =
		# nonblock: true
		animate_speed: 700
		opacity: 0.9
		animation:
			effect_in: 'drop'
			options_in: direction: 'up'
			effect_out: 'drop'
			options_out: direction: 'right'
		mouse_reset: false	# Fixes pines notify bug in which jquery UI animations cause the notifications to get stuck when the user mouses over them.
	options = _.extend defaults, options
	$.pnotify options
