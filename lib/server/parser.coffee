module.exports = (user, notifications) ->
	_ = require 'underscore'
	validators = require('validator').validators
	tools = require '../util'
	
	request = require 'request'
	request.post
		url: 'http://winedora-staging.herokuapp.com/social/xoauth/'
		body: 'user=' + user.email + '&token=' + user.oauth.token + '&secret=' + user.oauth.secret
		, (err, response, body) ->
			throw err if err
			throw new Error if response.statusCode isnt 200

			imap = require 'imap'
			server = new imap.ImapConnection
				xoauth: body
				host: 'imap.gmail.com'
				port: 993
				secure: true

			server.connect (err) ->
				if err
					console.warn err
					return notifications.error 'There was a problem connecting to gmail.'
				
				server.openBox '[Gmail]/All Mail', true, (err, box) ->
					throw err if err

					criteria = [['FROM', user.email]]
					if previous = user.lastParsed
						criteria.unshift ['SINCE', previous]
					server.search criteria, (err, results) ->
						throw err if err

						mimelib = require 'mimelib'
						mails = []
						notifications.foundTotal results.length

						finish = ->
							notifications.done mails
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
									email = tools.trim to.address.toLowerCase()
									name = tools.trim to.name, ' \'"'
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
								notifications.completedEmail()

						fetch.once 'message', (msg) ->
							msg.on 'end', ->
								{name} = mimelib.parseAddresses(msg.headers.from[0])[0]
								notifications.foundName name

						fetch.on 'end', ->
							return finish()
