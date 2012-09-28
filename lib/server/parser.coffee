module.exports = (user, notifications) ->
	_s = require 'underscore.string'
	validators = require('validator').validators
	
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
					return notifications.error 'There was a problem connecting to gmail.'
				
				server.openBox '[Gmail]/All Mail', true, (err, box) ->
					throw err if err

					# TODO XXX XXX testing
					criteria = [['FROM', 'annie@redstar.com']]
					# criteria = [['FROM', user.email]]
					# TODO XXX XXX testing
					# if previous = user.dateParsedLast
					# 	criteria.unshift ['SINCE', previous]
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
									email = _s.trim to.address.toLowerCase()	# TODO I have to do this right? Probably.
									name = _s.trim(to.name) or email	# If the name is blank use the email instead.
									# Only added non-redstar people as contacts, exclude junk like "undisclosed recipients", and excluse yourself.
									blacklist = []	# TODO load blacklisted email from the database {and (email not in blacklist)} does that work?
									# TODO remove the 'in redstar' bit in the line below. Does 'not in ' work?
									if (validators.isEmail email) and (email isnt user.email) and (email.indexOf('redstar') is -1)
										mails.push
											subject: msg.headers.subject?[0]
											dateSent: new Date msg.headers.date?[0]
											recipientEmail: email
											recipientName: name
								notifications.completedEmail()

						fetch.once 'message', (msg) ->
							msg.on 'end', ->
								{name} = mimelib.parseAddresses(msg.headers.from[0])[0]
								notifications.foundName name

						fetch.on 'end', ->
							return finish()
