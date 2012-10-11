module.exports = (app) ->
	util = require './util'


	send = (template, options, locals = {}) ->
		locals.path = (url) ->
			'http://' + process.env.HOST + url

		app.render 'mail/' + template, locals, (err, html) ->
			throw err if err

			options.html = html
			options.from ?= 'Redfly Supreme Ninja <kbaranowski@redstar.com>'
			util.mail options


	# sendWelcome: (to) ->
	# 	send 'welcome',
	# 		to: to
	# 		subject: 'Thank you for joining Redfly!'
	# 		# Need to add 'title:' here

	sendNudge: (user, contacts) ->
		_ = require 'underscore'
		_s = require 'underscore.string'
		tools = require '../util'

		# TODO duplicates some logic in the client models. Maybe put said logic in a common place.
		names = []
		for contact in contacts
			if name = _.first(contact.names)
				names.push name
			else
				email = _.first(contact.emails)
				names.push email[...email.lastIndexOf('.')]
		nicknames = (tools.nickname(_.first(contact.names), _.first(contact.emails)) for contact in contacts)
		
		send 'nudge',
				to: user.email
				subject: 'Tell me more about ' + nicknames.join(', ') + '...'	# TODO Use _s.toSentenceSerial whenever it becomes available.
			,
			title: 'Hi ' + user.name + '!'
			names: names
