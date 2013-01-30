_ = require 'underscore'
xoa2 = require 'xoauth2'
imap = require 'imap-jtnt-xoa2'
models = require './models'
mailer = require './mail'


module.exports = (app, user, notifications = {}, cb) ->
	_ = require 'underscore'


	parse = (app, user, notifications, cb) ->
		util = require './util'
		validators = require('validator').validators

		generator = require('xoauth2').createXOAuth2Generator
			user: user.email
			clientId: process.env.GOOGLE_API_ID
			clientSecret: process.env.GOOGLE_API_SECRET
			refreshToken: user.oauth

		generator.getToken (err, token) ->
			throw err if err

			imap = require 'imap-jtnt-xoa2'
			server = new imap.ImapConnection
				host: 'imap.gmail.com'
				port: 993
				secure: true
				xoauth2: token

			server.connect (err) ->
				if err
					return cb new Error 'Problem connecting to gmail.'
				
				server.openBox '[Gmail]/All Mail', true, (err, box) ->
					if err
						console.warn err
						return cb new Error 'Problem opening mailbox.'

					criteria = [['FROM', user.email]]
					if previous = user.lastParsed
						criteria.unshift ['SINCE', previous]

					server.search criteria, (err, results) ->
						throw err if err

						mimelib = require 'mimelib'
						mails = []
						notifications.foundTotal? results.length

						finish = ->
							notifications.completedAllEmails?()
							enqueue app, user, notifications, mails, cb
							server.logout()

						if results.length is 0
							# Return statement is important, simply invoking the callback doesn't stop code from excuting in the current scope.
							return finish()

						fetch = server.fetch results,
							request:
								headers: ['from', 'to', 'subject', 'date']
						
						fetch.on 'message', (msg) ->
							msg.on 'end', ->
								for to in mimelib.parseAddresses msg.headers.to?[0]
									email = util.trim to.address.toLowerCase()

									junkChars = ' \'",<>'
									name = util.trim to.name, junkChars
									comma = name.indexOf ','
									if comma isnt -1
										name = name[comma + 1..] + ' ' + name[...comma]
										name = util.trim name, junkChars	# Trim the name again in case the swap revealed more junk.
									if (not name) or (validators.isEmail name)
										name = null

									# Only added non-redstar people as contacts, exclude junk like "undisclosed recipients", and excluse yourself.
									blacklist = require './blacklist'
									if (validators.isEmail email) and (email isnt user.email) and
											(_.last(email.split('@')) not in blacklist.domains) and
											(name not in blacklist.names) and
											(email not in blacklist.emails) and
											(name not in _.pluck(user.excludes, 'name')) and
											(email not in _.pluck(user.excludes, 'email'))
										mails.push
											subject: msg.headers.subject?[0]
											sent: new Date msg.headers.date?[0]
											recipientEmail: email
											recipientName: name
								notifications.completedEmail?()

						fetch.on 'end', ->
							return finish()


	enqueue = (app, user, notifications, mails, cb) ->

		newContacts = []

		finishedParsing = (user, newContacts) ->
			thismailer = mailer(app);
			user.lastParsed = new Date
			user.save (err) ->
				throw err if err

				if newContacts and newContacts.length isnt 0
					thismailer.sendNudge user, newContacts[...10], cb
				else
					thismailer.sendNewsletter user, cb

		sift = (index = 0) ->
			if mails.length is 0
				return finishedParsing user

			mail = mails[index]
			# Find an existing contact with one of the same emails or names.
			models.Contact.findOne $or: [{emails: mail.recipientEmail}, {names: mail.recipientName}], (err, contact) ->
				throw err if err
				if not contact
					contact = new models.Contact
					contact.emails.addToSet mail.recipientEmail
					if name = mail.recipientName
						contact.names.addToSet name

					newContacts.push contact
					notifications.foundNewContact?()

				contact.knows.addToSet user
				contact.save (err) ->
					throw err if err
					mail.sender = user
					mail.recipient = contact
					models.Mail.create mail, (err) ->
						throw err if err

						index++
						if index < mails.length
							return sift index	# Wee recursion!

						newContacts = _.sortBy newContacts, (contact) ->
							_.chain(mails)
								.filter (mail) ->
									mail.recipient is contact
								.max (mail) ->
									mail.sent.getTime() # TO-DO probably can be just mail.sent
								.value()
						newContacts.reverse()
						user.queue.unshift newContacts...
						finishedParsing user, newContacts

		sift()


	parse app, user, notifications, cb
