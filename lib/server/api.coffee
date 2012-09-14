module.exports = (app, socket) ->
	_ = require 'underscore'
	models = require './models'


	session = socket.handshake.session

	socket.on 'session', (fn) ->
		fn session

	socket.on 'db', (data, fn) ->	# TODO probably need a big error catchall so every wrong query or mistyped url doesn't crash the server.
		model = models[data.type]
		switch data.op
			when 'find'
				if id = data.id
					model.findById id, (err, doc) ->
						throw err if err
						return fn doc
				else if ids = data.ids
					model.find '_id': $in: ids, (err, docs) ->
						throw err if err
						return fn docs
				else if query = data.query
					model.find query, (err, docs) ->
						throw err if err
						return fn docs
				else
					model.find (err, docs) ->
						throw err if err
						return fn docs
			when 'create'
				details = data.details
				if not _.isArray details
					model.create details, (err, doc) ->
						throw err if err
						return fn doc
				else
					model.create details, (err, docs...) ->
						throw err if err
						return fn docs
			when 'save'
				# TODO use model.save() to get validators and middleware
				throw new Error 'unimplemented'
			when 'delete'
				if id = data.id
					model.findByIdAndRemove id, (err) ->
						throw err if err
						return fn()
				else if ids = data.ids
					# TODO Remove each one and call return fn() when they're ALL done
					throw new Error 'unimplemented'
				else
					throw new Error
			else
				throw new Error


	socket.on 'signup', (email, fn) ->
		models.User.findOne email: email, (err, user) ->
			throw err if err
			if user
				return fn()
			oauth = require 'oauth-gmail'
			client = oauth.createClient callbackUrl: 'http://' + process.env.HOST + '/authorized'
			client.getRequestToken email, (err, result) ->  # TODO XXX try mistyping an email and see what happens
				throw err if err
				session.authorizeData = email: email, request: result
				session.save()
				return fn result.authorizeUrl

	socket.on 'login', (email, fn) ->
		models.User.findOne email: email, (err, user) ->
			throw err if err
			# TODO do authentication, either openID or: if user and user.password is req.body.password
			if not user
				return fn()
			session.user = user.id
			session.save()
			return fn user.id

	socket.on 'logout', (fn) ->
		session.destroy() # TODO This might not work right because of the way socket connections and sessions are 1:1
		fn()





	socket.on 'parse', (id, fn) ->
		# TODO have a check here to see when the last time the user's contacts were parsed was. People could hit the url for this by accident.
		models.User.findById id, (err, user) ->
			throw err if err

			notifications =
				foundName: (name) ->
					if not user.name
						user.name = name
						user.save (err) ->
							throw err if err
				foundTotal: (total) ->
					socket.emit 'parse.start', total
				completedEmail: ->
					socket.emit 'parse.update'
				done: (mails) ->	# TODO probably move the meat (db saving stuff) of this function elsewhere. Don't forget params to it like 'user'
					newContacts = []

					moar = ->	# TODO can i define this below 'sift'? Actually just put it in 'sift' and try to make it a self-calling function
						# If there were new contacts, determine those with the most correspondence and send a nudge email.
						if newContacts.length isnt 0
							newContacts = _.sortBy newContacts, (contact) ->
								_.reduce mails, (mail, total) ->
										if contact.email is mail.recipientEmail
											return total - 1	# Negative totals to reverse the order!
										return total
									, 0
							newContacts = newContacts[...5]								

							user.classifyIndex = user.classify.toObject().length - 1	# TODO necessary toObject?
							user.classify.push newContacts...

							mail = require('./mail')(app)
							mail.sendNudge user, newContacts

						user.dateParsedLast = Date.now()
						user.save (err) ->
							throw err if err

						fn()

					sift = (index = 0) ->
						mail = mails[index]
						mail.sender = user

						models.Contact.findOne email: mail.recipientEmail, (err, contact) ->
							throw err if err

							if not contact
								contact = new models.Contact
								contact.email = mail.recipientEmail
								contact.name = mail.recipientName
								contact.knows.push user

								newContacts.push contact
							else
								validators = require('validator').validators
								# Sometimes the contact's name and email are the same in the system because they were emailed without an a name
								# explicitly set in the "to" field. Overwrite the old name if we have a better one this time around.
								if validators.isEmail contact.name
									contact.name = mail.recipientName
								contact.knows.addToSet user

							contact.save (err) ->
								throw err if err

								mail.recipient = contact
								models.Mail.create mail, (err, doc) ->
									throw err if err

									index++
									if index < mails.length
										return sift index	# Wee recursion!
									moar()

					sift()

			require('./parser')(user, notifications)
