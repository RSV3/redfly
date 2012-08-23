module.exports = (user, notifications) ->
	
	# TODO XXX generate xoauth, steal code from test.coffee
	xoauth = 'R0VUIGh0dHBzOi8vbWFpbC5nb29nbGUuY29tL21haWwvYi9rYmFyYW5vd3NraUByZWRzdGFyLmNvbS9pbWFwLyBvYXV0aF9jb25zdW1lcl9rZXk9ImFub255bW91cyIsb2F1dGhfbm9uY2U9Ijg4Mjg3MTg0MDIyNjAwODc0OTgiLG9hdXRoX3NpZ25hdHVyZT0iVFp5U3M3Y1JQQ2VES24yV0lZUSUyRjRDRjNLd2slM0QiLG9hdXRoX3NpZ25hdHVyZV9tZXRob2Q9IkhNQUMtU0hBMSIsb2F1dGhfdGltZXN0YW1wPSIxMzQ1NzMyMjA2IixvYXV0aF90b2tlbj0iMSUyRnl5cGZrVjJGbVNfMkJIRW9tVEhZaVlQRldyOU12N1NQN19JaXA5NU5waDgiLG9hdXRoX3ZlcnNpb249IjEuMCI='

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

			# criteria = [['FROM', user.email]]
			# TODO XXX temporary, for testing
			criteria = [['FROM', 'annie@redstar.com']]
			if previous = user.last_parse_date
				criteria.unshift ['SINCE', previous]
			server.search criteria, (err, results) ->
				throw err if err

				mimelib = require 'mimelib'
				contacts = {}
				notifications.foundTotal results.length

				fetch = server.fetch results,
					request:
						headers: ['from', 'to', 'subject', 'date']
				
				fetch.on 'message', (msg) ->
					msg.on 'end', ->
						for to in mimelib.parseAddresses msg.headers.to[0]
							email = to.address.toLowerCase()
							# Only added non-redstar people as contacts, exclude junk like "undisclosed recipients", and excluse yourself.
							if email and (email.indexOf('@') isnt -1)
								if contact = contacts[email]
									contact.knows[user.id].count++
								else
									contact =
										name: to.name
										email: email
										date: +new Date
										added_by: user.id # TODO XXX temporary for testing
										knows: {}
									contact.knows[user.id] =
										first_email:
											date: new Date msg.headers.date[0]
											subject: msg.headers.subject[0]
										count: 1
									contacts[email] = contact
						notifications.completedEmail()

				fetch.once 'message', (msg) ->
					msg.on 'end', ->
						{name} = mimelib.parseAddresses(msg.headers.from[0])[0]
						notifications.foundName name

				fetch.on 'end', ->
					notifications.done contacts
					server.logout()
