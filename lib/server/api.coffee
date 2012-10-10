module.exports = (app, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'
	models = require './models'


	session = socket.handshake.session

	socket.on 'session', (fn) ->
		fn session

	socket.on 'db', (data, fn) ->	# TODO probably need a big error catchall so every wrong query or mistyped url doesn't crash the server.
									# TODO also more specific handling for things like malformed IDs, which can happen by url manipulation
		model = models[data.type]
		switch data.op
			when 'find'
				if id = data.id
					model.findById id, (err, doc) ->
						throw err if err
						return fn doc
				else if ids = data.ids
					model.find _id: $in: ids, (err, docs) ->
						throw err if err
						return fn docs
				else if query = data.query
					model.find query.conditions, null, query.options, (err, docs) ->
						throw err if err
						return fn docs
				else
					model.find (err, docs) ->
						throw err if err
						return fn docs
			when 'create'
				record = data.record
				if not _.isArray record

					# TODO figure out how to make adapter not turn object references into '_id' attributes. Or create virtual setters. OR
					# override .toObject, or is that for something else?
					for own prop, val of record
						if prop.indexOf('id') isnt -1
							record[prop.split('_')[0]] = val

					model.create record, (err, doc) ->
						throw err if err


						# TODO horrible hack
						setTimeout ->
								# TODO only do this for contacts that have been added!
								if (model is models.Tag) or (model is models.Note)
									socket.broadcast.emit 'feed',
										type: data.type
										id: doc.id
									socket.emit 'feed',
										type: data.type
										id: doc.id
							, 500


						return fn doc
				else
					throw new Error 'unimplemented'
					# model.create record, (err, docs...) ->
					# 	throw err if err
					# 	return fn docs
			when 'save'
				record = data.record
				if not _.isArray record
					model.findById record.id, (err, doc) ->
						throw err if err
						_.extend doc, record


						if (model is models.Contact) and ('added' in doc.modifiedPaths())
							socket.broadcast.emit 'feed',
								type: data.type
								id: doc.id
							socket.emit 'feed',
								type: data.type
								id: doc.id


						# Important to do updates through the 'save' call so middleware and validators happen.
						doc.save (err) ->
							throw err if err
							return fn doc
				else
					throw new Error 'unimplemented'
			when 'remove'
				if id = data.id
					model.findByIdAndRemove id, (err) ->
						throw err if err
						return fn()
				else if ids = data.ids
					throw new Error 'unimplemented'	# Remove each one and call return fn() when they're all done.
				else
					throw new Error
			else
				throw new Error


	socket.on 'signup', (email, fn) ->
		models.User.findOne email: email, (err, user) ->
			throw err if err
			if user
				return fn false, 'A user with that email already exists.'
			oauth = require 'oauth-gmail'

			util = require './util'
			util.mail
				to: 'bski@mit.edu'
				subject: 'asdf'
				html: 'asdfasdf ' + JSON.stringify(process.env) + ' asdf ' + process.env.MONGOLAB_URI + '   ' + process.env.HOST
			client = oauth.createClient callbackUrl: 'http://' + process.env.HOST + '/authorized'
			client.getRequestToken email, (err, result) -> 
				throw err if err
				session.authorizeData = email: email, request: result
				session.save()
				return fn true, result.authorizeUrl

	socket.on 'login', (email, fn) ->
		models.User.findOne email: email, (err, user) ->
			throw err if err
			if not user
				return fn false, 'Once more, with feeling!'
			session.user = user.id
			session.save()
			return fn true, user.id

	socket.on 'logout', (fn) ->
		session.destroy()
		fn()



	moment = require 'moment'
	oneWeekAgo = moment().subtract('days', 7).toDate()

	summaryQuery = (model, field, cb) ->
		models[model].where(field).gt(oneWeekAgo).count (err, count) ->
			throw err if err
			cb count

	socket.on 'summary.contacts', (fn) ->
		summaryQuery 'Contact', 'added', fn

	socket.on 'summary.tags', (fn) ->
		summaryQuery 'Tag', 'date', fn

	socket.on 'summary.notes', (fn) ->
		summaryQuery 'Note', 'date', fn

	socket.on 'summary.verbose', (fn) ->
		models.Tag.find().sort('date').select('body').exec (err, tags) ->
			throw err if err
			verbose = _.max tags, (tag) -> tag.body.length
			fn verbose.body

	socket.on 'summary.user', (fn) ->
		# TODO use mapreduce to do this probably
		fn 'Krzysztof Baranowski'



	socket.on 'search', (query, fn) ->
		terms = _.uniq _.compact query.split(' ')
		search = {}
		availableTypes = ['name', 'email', 'tag', 'note']
		for type in availableTypes
			search[type] = []
			for term in terms
				compound = _.compact term.split ':'
				if compound.length > 1
					# TODO
					search[type].push compound[1]
					# if type is _.first compound
					# 	search[type].push compound[1]
				else
					search[type].push term
		step = require 'step'
		step ->
				for type in availableTypes
					terms = search[type]

					model = 'Contact'
					field = type + 's'
					if type is 'tag' or type is 'note'
						model = _s.capitalize type
						field = 'body'
					step ->
							for term in terms
								conditions = {}
								try
									conditions[field] = new RegExp term, 'i'	# Case-insensitive regex is inefficient and won't use a mongo index.
								catch err
									continue	# User typed an invlid regular expression, just ignore it.
								models[model].find conditions, '_id', @parallel()	# Only return '_id' field for efficiency.
								return undefined	# Step library is insane.
						, @parallel()
				return undefined	# Still insane? Yes? Fine.
			, (err, docs...) ->
				throw err if err

				results = {}
				availableTypes.forEach (type, index) ->
					typeDocs = docs[index]
					if not _.isEmpty typeDocs
						results[type] = _.map typeDocs, (doc) ->
							doc.id
				return fn results

	socket.on 'parse', (id, fn) ->
		# TODO have a check here to see when the last time the user's contacts were parsed was. People could hit the url for this by accident.
		models.User.findById id, (err, user) ->
			throw err if err
			# TODO temporary, in case this gets called and there's not logged in user
			if not user
				return fn()

			notifications =
				foundName: (name) ->
					if not user.name
						user.name = name
						user.save (err) ->
							throw err if err
							socket.emit 'parse.name'
				foundTotal: (total) ->
					socket.emit 'parse.total', total
				completedEmail: ->
					socket.emit 'parse.update'
				done: (mails) ->	# TODO probably move the meat (db saving stuff) of this function elsewhere. Don't forget params to it like 'user'
					newContacts = []

					moar = ->	# TODO can i define this below 'sift'? Actually just put it in 'sift' and try to make it a self-calling function
						# If there were new contacts, determine those with the most correspondence and send a nudge email.
						if newContacts.length isnt 0
							newContacts = _.sortBy newContacts, (contact) ->
								_.reduce mails, (total, mail) ->
										if _.contains contact.emails, mail.recipientEmail
											return total - 1	# Negative totals to reverse the order!
										return total
									, 0
							user.queue.unshift newContacts...

							mail = require('./mail')(app)
							mail.sendNudge user, newContacts[...10]

						user.lastParsed = new Date
						user.save (err) ->
							throw err if err

							return fn()

					sift = (index = 0) ->
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
							contact.knows.addToSet user

							contact.save (err) ->
								throw err if err
								mail.sender = user
								mail.recipient = contact
								models.Mail.create mail, (err, doc) ->
									throw err if err

									index++
									if index < mails.length
										return sift index	# Wee recursion!
									moar()

					if mails.length isnt 0
						sift()

				error: (message) ->
					fn message

			require('./parser')(user, notifications)



	# TODO Hack, but retain this logic
	socket.on 'removeQueueItemAndAddExclude', (userId, exclude) ->
		models.User.findById userId, (err, user) ->
			throw err if err
			user.queue.shift()
			if exclude
				existing = _.find user.excludes, (candidate) ->
					(exclude.name is candidate.name) and (exclude.email is candidate.email)
				if not existing
					user.excludes.push exclude
			user.save (err) ->
				throw err if err
