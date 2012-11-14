module.exports = (app, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'

	models = require './models'
	logic = require './logic'


	session = socket.handshake.session

	socket.on 'session', (fn) ->
		fn session

	socket.on 'db', (data, fn) ->
		model = models[data.type]
		switch data.op
			when 'find'
				if id = data.id
					model.findById id, (err, doc) ->
						throw err if err
						return fn doc
				# else if ids = data.ids
				# 	model.find _id: $in: ids, (err, docs) ->
				# 		throw err if err
				# 		return fn docs
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
					model.create record, (err, doc) ->
						throw err if err
						fn doc
						if (model is models.Tag) or (model is models.Note)
							socket.broadcast.emit 'feed',
								type: data.type
								id: doc.id
							socket.emit 'feed',
								type: data.type
								id: doc.id
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
						broadcast = false
						if (model is models.Contact) and ('added' in doc.modifiedPaths())
							broadcast = true
						# Important to do updates through the 'save' call so middleware and validators happen.
						doc.save (err) ->
							throw err if err
							fn doc
							if broadcast
								socket.broadcast.emit 'feed',
									type: data.type
									id: doc.id
								socket.emit 'feed',
									type: data.type
									id: doc.id
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
			# session.user = user.id
			# session.save()
			# return fn true, user.id

			# Tempoarily use of the authorize flow for login. Copy/pasted.
			oauth = require 'oauth-gmail'
			client = oauth.createClient callbackUrl: 'http://' + process.env.HOST + '/authorized'
			client.getRequestToken email, (err, result) -> 
				throw err if err
				session.authorizeData = email: email, request: result
				session.save()
				return fn true, result.authorizeUrl

	socket.on 'logout', (fn) ->
		session.destroy()
		fn()



	socket.on 'summary.contacts', (fn) ->
		logic.summaryContacts (err, count) ->
			throw err if err
			fn count

	socket.on 'summary.tags', (fn) ->
		logic.summaryTags (err, count) ->
			throw err if err
			fn count

	socket.on 'summary.notes', (fn) ->
		logic.summaryNotes (err, count) ->
			throw err if err
			fn count

	socket.on 'summary.verbose', (fn) ->
		models.Tag.find().sort('date').select('body').exec (err, tags) ->
			throw err if err
			verbose = _.max tags, (tag) ->
				tag.body.length
			fn verbose?.body

	socket.on 'summary.user', (fn) ->
		fn 'Joe Chung'



	socket.on 'verifyUniqueness', (id, field, candidates, fn) ->
		models.Contact.findOne().ne('_id', id).in(field, candidates).exec (err, contact) ->
			throw err if err
			fn _.chain(contact?[field])
				.intersection(candidates)
				.first()
				.value()

	socket.on 'tags', (conditions, fn) ->
		models.Tag.find(conditions).distinct 'body', (err, bodies) ->
			throw err if err
			fn bodies

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

								# TODO temporary
								if model is 'Contact'
									conditions.added = $exists: true
								
								models[model].find(conditions).limit(10).exec @parallel()
								return undefined	# Step library is insane.
						, @parallel()
				return undefined	# Still insane? Yes? Fine.
			, (err, docs...) ->
				throw err if err

				results = {}
				availableTypes.forEach (type, index) ->
					typeDocs = docs[index]
					if not _.isEmpty typeDocs
						if type is 'tag' or type is 'note'
							typeDocs = _.uniq typeDocs, false, (typeDoc) ->
								typeDoc.contact.toString()	# Convert ObjectId object to a simple string.
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
					socket.emit 'parse.mail'
				completedAllEmails: ->
					socket.emit 'parse.queueing'
				foundNewContact: ->
					socket.emit 'parse.enqueued'

			require('./parser') app, user, notifications, fn
