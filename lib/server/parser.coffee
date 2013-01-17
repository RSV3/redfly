_ = require 'underscore'
xoa2 = require 'xoauth2'
imap = require 'imap-jtnt-xoa2'
util = require './util'
models = require './models'
mailer = require './mail'
validators = require('validator').validators


module.exports = (app, user, notifications = {}, cb) ->

	parse = (app, user, notifications, cb) ->

		opts =
			user: user.email
			clientId: process.env.GOOGLE_API_ID
			clientSecret: process.env.GOOGLE_API_SECRET
			refreshToken: user.oauth.refreshToken
		client = xoa2.createXOAuth2Generator opts

		client.getToken (err, token) ->

			opts = 
				host: 'imap.gmail.com'
				port: 993
				secure: true
				xoauth2: token

			server = new imap.ImapConnection opts

			server.connect (err) ->

				if err
					console.log "ERR in server"
					console.warn err
					console.dir opts
					return;
				
				server.openBox '[Gmail]/All Mail', true, (err, box) ->
					if err
						console.log "ERR in openBox"
						console.log err
						throw err

					criteria = [['FROM', user.email]]
					if previous = user.lastParsed
						criteria.unshift ['SINCE', previous]

					server.search criteria, (err, results) ->
						if err
							console.log "search err"
							console.dir err

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
									else
										console.log 'blacklisting'
										console.dir
											subject: msg.headers.subject?[0]
											sent: new Date msg.headers.date?[0]
											recipientEmail: email
											recipientName: name

								notifications.completedEmail?()

						fetch.once 'message', (msg) ->
							msg.on 'end', ->
								{name} = mimelib.parseAddresses(msg.headers.from[0])[0]
								notifications.foundName? name

						fetch.on 'end', ->
							return finish()


	enqueue = (app, user, notifications, mails, cb) ->

		newContacts = []

		finishedParsing = () ->
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
