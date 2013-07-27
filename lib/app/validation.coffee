module.exports = (socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'
	async = require 'async'
	validators = require('validator').validators

	blacklist = require '../blacklist'
	util = require '../util'


	messages =
		required: 'Dudebro, you have to enter something dude.'
		requiredSet: (value) ->
			'A contact must have at least one ' + value + '.'
		format: (value) ->
			'Pretty sure that\'s not a valid ' + value + '.'
		unique: (value) ->
			'There is another contact with that ' + value + '.'
		blacklisted: "blacklisted"
	
	filter:
		general:
			picture: (picture) ->
				if picture
					picture = util.trim picture
					if not _s.startsWith picture, 'http'
						picture = 'http://' + picture
					picture
		contact:
			emails: (emails) ->
				_.compact _.map emails, (item) => @email item
			email: (email) ->
				if email then util.trim email.toLowerCase()
			names: (names) ->
				_.compact _.map names, (item) => @name item
			name: (name) ->
				util.trim name
	validate:
		general:
			picture: (picture) ->
				if not validators.isUrl picture
					return messages.format 'URL'
		contact:
			emails: (emails, cb) ->
				if _.isEmpty emails
					return cb messages.requiredSet 'email'
				async.forEach emails, @email, cb
			email: (email, cb) ->
				if not email
					return cb messages.required
				if not validators.isEmail email
					return cb messages.format 'email'
				if (_.last(email.split('@')) in blacklist.domains) or (email in blacklist.emails)
					return cb messages.blacklisted
				socket.emit 'verifyUniqueness', field: 'email', value: email, (duplicate) ->
					if duplicate
						return cb messages.unique 'email'
					cb()
			names: (names, cb) ->
				if _.isEmpty names
					return cb messages.requiredSet 'name'
				async.forEach names, @name, cb
			name: (name, cb) ->
				if not name
					return cb messages.required
				if name in blacklist.names
					return cb messages.blacklisted
				socket.emit 'verifyUniqueness', field: 'name', value: name, (duplicate) ->
					if duplicate
						return cb messages.unique 'name'
					cb()
