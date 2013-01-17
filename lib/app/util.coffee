util = module.exports = require '../util'


util.notify = (options) ->
	_ = require 'underscore'

	_.defaults options,
		# nonblock: true
		animate_speed: 700
		opacity: 0.9
		animation:
			effect_in: 'drop'
			options_in: direction: 'up'
			effect_out: 'drop'
			options_out: direction: 'right'
		mouse_reset: false	# Fixes pines notify bug in which jquery UI animations cause the notifications to get stuck when the user mouses over them.
	$.pnotify options
