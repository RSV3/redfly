module.exports = (user, notifications) ->
	_ = require 'underscore'	
	
	request = require 'request'
	request.post
		url: 'http://winedora-staging.herokuapp.com/social/xoauth/'
		body: 'user=' + user.email + '&token=' + user.oauth.token + '&secret=' + user.oauth.secret
		, (err, response, body) ->
			throw err if err
			throw new Error if response.statusCode isnt 200
			xoauth = body

			imap = require 'imap'
			server = new imap.ImapConnection
				xoauth: xoauth
				host: 'imap.gmail.com'
				port: 993
				secure: true

			server.connect (err) ->
				throw err if err
				server.openBox '[Gmail]/All Mail', true, (err, box) ->
					throw err if err

					# TODO XXX testing
					# criteria = [['FROM', 'annie@redstar.com']]
					criteria = [['FROM', user.email]]
					if previous = user.last_parse_date
						criteria.unshift ['SINCE', previous]
					server.search criteria, (err, results) ->
						throw err if err

						mimelib = require 'mimelib'
						data = {}
						notifications.foundTotal results.length

						finish = ->
							notifications.done data
							server.logout()

						if results.length is 0
							# Return statement is important, simple invoking the callback doesn't stop code from excuting in the current scope.
							return finish()
						fetch = server.fetch results,
							request:
								headers: ['from', 'to', 'subject', 'date']
						fetch.on 'message', (msg) ->
							msg.on 'end', ->
								for to in mimelib.parseAddresses msg.headers.to?[0]
									email = _.str.trim to.address.toLowerCase()
									name = _.str.trim(to.name) or email	# If the name is blank, use the email instead.
									# Only added non-redstar people as contacts, exclude junk like "undisclosed recipients", and excluse yourself.
									if email and (_.str.contains email, '@') and
											(email isnt user.email) and
											(not _.str.contains email, '@redstar.com') and
											(not _.str.contains email, '@nevershopalone.com') and
											(not _.str.contains email, '@gosprout.com') and
											(not _.str.contains email, '@vinely.com') and
											(not _.str.contains email, '@vine.ly')
										if datum = data[email]
											contact = datum.contact
											if _.str.contains contact.name, '@'
												contact.name = name
											datum.history.count++
										else
											data[email] =
												contact:
													name: name
													email: email
													date: +new Date
													knows: [user.id]
												history:
													date: +new Date
													user: user.id
													first_email:
														date: new Date msg.headers.date?[0]
														subject: msg.headers.subject?[0]
													count: 1
								notifications.completedEmail()

						fetch.once 'message', (msg) ->
							msg.on 'end', ->
								{name} = mimelib.parseAddresses(msg.headers.from[0])[0]
								notifications.foundName name

						fetch.on 'end', ->
							return finish()
