passport = require 'passport'
GoogleStrategy = require('passport-google-oauth').OAuth2Strategy

util = require './util'
models = require './models'

module.exports = (app, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'

	logic = require './logic'

	session = socket.handshake.session

	authCallBack = (access, refresh, profile, done) ->
		if profile._json.email isnt session.email
			session.wrongemail = profile._json.email
			session.save()
			done false, null
		else models.User.findOne email: profile._json.email, (err, user) ->
			throw err if err
			if not user
				user = new models.User
				user.email = profile._json.email
				user.name = profile._json.name
				user.oauth = {}
			user.oauth.accessToken = access
			if refresh
				user.oauth.refreshToken = refresh
			user.save (err) ->
				done err, user

	passport.use(new GoogleStrategy {
			clientID: process.env.GOOGLE_API_ID
			clientSecret: process.env.GOOGLE_API_SECRET
			callbackURL: util.baseUrl + '/authorized'
		}, authCallBack)

	app.get '/force-authorize', passport.authenticate('google', 
		scope: ['https://www.googleapis.com/auth/userinfo.profile', 'https://www.googleapis.com/auth/userinfo.email', 'https://mail.google.com/', 'https://www.google.com/m8/feeds'] 
		approvalPrompt: 'force'
		accessType: 'offline'
	), (err, user, info) ->
			console.log 'never gets here'

	app.get '/authorize', passport.authenticate('google', 
		scope: ['https://www.googleapis.com/auth/userinfo.profile', 'https://www.googleapis.com/auth/userinfo.email', 'https://mail.google.com/', 'https://www.google.com/m8/feeds'] 
#		approvalPrompt: 'force'
		accessType: 'offline'
	), (err, user, info) ->
			console.log 'never gets here'

	app.get '/authorized', (req, res, next) ->
		passport.authenticate('google',  (err, user, info) ->
			if not user
				console.log('wrong email: ' + session.wrongemail)
				res.redirect '/profile'
			else 
				req.login user, {}, (err) ->
					if err then return next err
					if not user.oauth.refreshToken
						console.log 'attempting to force new refresh token'
						return res.redirect '/force-authorize'
					else 
						if user.lastParsed 
							yesterday = new Date()
							yesterday.setDate(yesterday.getDate() - 1)
							if user.lastParsed > yesterday
								return res.redirect "/profile"
						return res.redirect "/load"
		) req, res, next

	socket.on 'session', (fn) ->
		fn session

	socket.on 'db', (data, fn) ->
		feed = (data, doc) ->
			socket.broadcast.emit 'feed',
				type: data.type
				id: doc.id
			socket.emit 'feed',
				type: data.type
				id: doc.id

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
					model.create record, (err, doc) ->
						throw err if err
						fn doc
						if (model is models.Contact) or (model is models.Tag) or (model is models.Note)
							feed data, doc
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
						broadcast = (model is models.Contact) and ('added' in doc.modifiedPaths())
						# Important to do updates through the 'save' call so middleware and validators happen.
						doc.save (err) ->
							throw err if err
							fn doc
							if broadcast
								feed data, doc
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
			session.email = email
			session.save()
			return fn true, '/force-authorize'


	socket.on 'login', (email, fn) ->
		models.User.findOne email: email, (err, user) ->
			throw err if err
			if not user
				return fn false, 'Once more, with feeling!'
			session.email = email
			session.save()
			if user.oauth.refreshToken
				return fn true, '/authorize'
			return fn true, '/force-authorize'

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



	socket.on 'search', (query, moreConditions, fn) ->
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

								if model is 'Contact'
									conditions.added = $exists: true
									_.extend conditions, moreConditions
								# else
								# 	for k, v of moreConditions
								# 		conditions['contact.' + k] = v
								
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
								typeDoc.contact.toString()	# Convert ObjectId to a simple string.
						results[type] = _.map typeDocs, (doc) ->
							doc.id
				return fn results

	socket.on 'verifyUniqueness', (field, value, fn) ->
		field += 's'
		conditions = {}
		conditions[field] = value
		models.Contact.findOne conditions, (err, contact) ->
			throw err if err
			fn contact?[field][0]

	socket.on 'deprecatedVerifyUniqueness', (id, field, candidates, fn) ->	# Deprecated, bitches
		models.Contact.findOne().ne('_id', id).in(field, candidates).exec (err, contact) ->
			throw err if err
			fn _.chain(contact?[field])
				.intersection(candidates)
				.first()
				.value()

	socket.on 'tags.all', (conditions, fn) ->
		models.Tag.find(conditions).distinct 'body', (err, bodies) ->
			throw err if err
			fn bodies

	socket.on 'tags.popular', (conditions, fn) ->
		models.Tag.aggregate {$match: conditions},
			{$group:  _id: '$body', count: $sum: 1},
			{$sort: count: -1},
			{$project: _id: 0, body: '$_id'},
			{$limit: 12},
			(err, results) ->
				throw err if err
				fn _.pluck results, 'body'

	socket.on 'tags.stats', (fn) ->
		group =
			$group:
				_id: '$body'
				count: $sum: 1
				mostRecent: $max: '$date'
				# contacts: $addToSet: '$contacts'
		project =
			$project:
				_id: 0
				body: '$_id'
				count: 1
				mostRecent: 1
		models.Tag.aggregate group, project, (err, results) ->
				throw err if err
				fn results
		# fn [
		# 	{body: 'capitalism', count: 56, mostRecent: new Date()}
		# 	{body: 'communism', count: 4, mostRecent: require('moment')().subtract('days', 7).toDate()}
		# 	{body: 'socialism', count: 110, mostRecent: require('moment')().subtract('days', 40).toDate()}
		# 	{body: 'fascism', count: 61, mostRecent: require('moment')().subtract('days', 40).toDate()}
		# 	{body: 'vegetarianism', count: 5, mostRecent: require('moment')().subtract('days', 40).toDate()}
		# ]

	socket.on 'merge', (contactId, mergeIds, fn) ->
		models.Contact.findById contactId, (err, contact) ->
			throw err if err
			models.Contact.find().in('_id', mergeIds).exec (err, merges) ->
				throw err if err

				history = new models.Merge
				history.contacts = [contact].concat merges...
				history.save (err) ->
					throw err if err

				async = require 'async'
				async.forEach merges, (merge, cb) ->
					for field in ['names', 'emails', 'knows']
						contact[field].addToSet merge[field]...
					for field in ['picture', 'added', 'addedBy']
						if (value = merge[field]) and not contact[field]
							contact[field] = value
					async.forEach [{type: 'Tag', field: 'contact'}, {type: 'Note', field: 'contact'}, {type: 'Mail', field: 'recipient'}], (update, cb) ->
						conditions = {}
						conditions[update.field] = merge.id
						models[update.type].find conditions, (err, docs) ->
							throw err if err
							async.forEach docs, (doc, cb) ->
								doc[update.field] = contact
								doc.save (err) ->
									# If there's a duplicate key error that means the same tag is on two contacts, just delete the other one.
									if err?.code is 11001
										doc.remove cb
									else
										cb err
							, (err) ->
								cb err
					, (err) ->
						throw err if err
						merge.remove cb
				, (err) ->
					contact.save (err) ->
						throw err if err
						return fn()

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

			try
				require('./parser') app, user, notifications, fn
			catch e
				console.log "PARSER ERR"
				console.log e

