module.exports = (socket) ->
	_ = require 'underscore'
	validators = require('validator').validators

	util = require '../util'


	messages =
		required: 'Dudebro, you have to enter something dude, bro.'
		format: (value) ->
			'Pretty sure that\'s not a valid ' + value + '.'
		unique: (value) ->
			'There is another contact with that ' + value + '.'
	
	filter:
		general:
			picture: (picture) ->
				util.trim picture
		contact:
			# emails: (emails) ->
			# 	_.chain(emails)
			# 		.map (item) ->
			# 			util.trim item
			# 		.compact()
			# 		.value()
			email: (email) ->
				if email
					util.trim email.toLowerCase()
			name: (name) ->
				util.trim name
	validate:
		general:
			picture: (picture) ->
				if not validators.isUrl picture
					return messages.format 'URL'
		contact:
			# emails: (emails) ->
			# 	if _.isEmpty emails
			# 		message.required
			email: (email, cb) ->
				if not email
					return cb messages.required
				if not validators.isEmail email
					return cb messages.format 'email'
				socket.emit 'verifyUniqueness', 'email', email, (duplicate) ->
					if duplicate
						return cb messages.unique 'email'
					cb()
			# names: (names) ->
			# 	if _.isEmpty names
			# 		message.required
			name: (name, cb) ->
				if not name
					return cb messages.required
				socket.emit 'verifyUniqueness', 'name', name, (duplicate) ->
					if duplicate
						return cb messages.unique 'name'
					cb()
