module.exports = (app) ->
	util = require './util'


	send = (template, options, locals = {}, cb) ->
		locals.path = (url) ->
			'http://' + process.env.HOST + url

		app.render 'mail/' + template, locals, (err, html) ->
			throw err if err

			options.html = html
			options.from ?= 'His Serene Highness of Redfly <kbaranowski@redstar.com>'
			util.mail options, cb


	# sendWelcome: (to, cb) ->
	# 	send 'welcome',
	# 			to: to
	# 			subject: 'Thank you for joining Redfly!'
	# 			# Need to add 'title:' here
	#		, {}, cb

	sendNudge: (user, contacts, cb) ->
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
				splitted = email.split '@'
				domain = _.first _.last(splitted).split('.')
				names.push _.first(splitted) + ' [' + domain + ']'
		nicknames = (tools.nickname(_.first(contact.names), _.first(contact.emails)) for contact in contacts)
		
		send 'nudge',
				to: user.email
				subject: 'Tell me more about ' + nicknames.join(', ') + '...'	# TODO Use _s.toSentenceSerial whenever it becomes available.
			,
				title: 'Hi ' + user.name + '!'
				names: names
			, cb

	sendNewsletter: (user, cb) ->
		logic = require './logic'
		require('step') ->
				logic.summaryContacts @parallel()
				logic.summaryTags @parallel()
				logic.summaryNotes @parallel()
				return undefined
			, (err, numContacts, numTags, numNotes) ->
				throw err if err
				send 'newsletter',
						to: user.email
						subject: 'On the Health and Well-Being of Redfly'
					,
						title: 'It\'s been a big week!'
						contactsQueued: numContacts
						tagsCreated: numTags
						notesAuthored: numNotes
					, cb
