
passport = require 'passport'
LinkedInStrategy = require('passport-jtnt-linkedin').Strategy

request = require 'request'



module.exports = (app, socket) ->

	_ = require 'underscore'
	_s = require 'underscore.string'

	logic = require './logic'
	util = require './util'
	models = require './models'

	session = socket.handshake.session

	linkCallBack = (token, secret, profile, done) ->
		if not profile
			return done "No profile", null
		li =
			id: profile.id
			token: token
			secret: secret
		models.User.findOne _id: session.user, (err, user) ->
			if err or not user
				console.log "ERROR: #{err} linking in for #{session.user}"
				return done err, null
			else
				if not user.picture and not profile._json?.pictureUrl?.match(/no_photo/)
					user.picture = profile._json?.pictureUrl
					dirtyflag = true
				if not user.linkedin or user.linkedin isnt profile.id
					user.linkedin = profile.id
					dirtyflag = true
				if dirtyflag
					user.save (err) ->
						return done err, user, li
				else
					return done null, user, li


	li_opts=
		consumerKey: process.env.LINKEDIN_API_KEY
		consumerSecret: process.env.LINKEDIN_API_SECRET
		callbackURL: util.baseUrl + '/linked'
		scope:['r_basicprofile', 'r_fullprofile', 'r_network']
		fetch:['picture-url', 'id']

	console.log ""
	console.log "using passport to link in with:"
	console.dir li_opts
	console.log ""
	passport.use(new LinkedInStrategy li_opts, linkCallBack)



	app.get '/force-authorize', passport.authenticate('google', 
		scope: ['https://www.googleapis.com/auth/userinfo.profile', 'https://www.googleapis.com/auth/userinfo.email', 'https://mail.google.com/', 'https://www.google.com/m8/feeds'] 
		approvalPrompt: 'force'
		accessType: 'offline'
	), (err, user, info) ->
			console.log 'never gets here'

	app.get '/authorized', (req, res, next) ->
		passport.authenticate('google',  (err, user, info) ->
			if not user
				console.log 'wrong email: #{session.wrongemail}'
				res.redirect '/profile'
			else 
				req.login user, {}, (err) ->
					if err then return next err
					if not user.oauth.refreshToken
						console.log 'attempting to force new refresh token'
						return res.redirect '/force-authorize'
					else 
						url = "https://www.googleapis.com/oauth2/v1/userinfo?access_token=#{user.oauth.accessToken}"
						request.get
							url: url
							json: true
						, (error, response, body) ->
							if body.picture and not user.picture
								console.log "if #{body.picture} and not #{user.picture}"
								user.picture = body.picture
								user.save (err) ->
									if err
										console.log "error saving user picture from gmail"
										console.dir err

						###
						#
						# notes:
						# this google contacts api picks out name and email:
						# need to do something to get image url
						#
						# even then, it's another api call, which allows us to download data.
						# do we wanna store images locally?

						GoogleContacts = require('Google-Contacts').GoogleContacts;
						c = new GoogleContacts
							token: user.oauth.accessToken
							refreshToken: user.oauth.refreshToken
							consumerKey: process.env.GOOGLE_API_ID
							consumerSecret: process.env.GOOGLE_API_SECRET

						c.on 'error', (e) ->
							  console.log('Google Contacts error: ', e);

						c.on 'contactsReceived', (contacts) ->
							  console.log 'contacts: '
							  console.dir contacts

						try
							c.getContacts (err, contacts) ->
								if err then console.log "error #{err}"
								console.dir contacts
						catch e
							console.log "getContacts error #{e}"

						###
						
						if user.lastParsed 
							yesterday = new Date()
							yesterday.setDate(yesterday.getDate() - 1)
							if user.lastParsed > yesterday
								return res.redirect "/profile"

						return res.redirect "/load"
		) req, res, next


	app.get '/linker', passport.authenticate('linkedin'), (err, user, info) ->
		console.log 'never gets here'

	app.get '/linked', (req, res, next) ->
		if req.params.oauth_problem is 'user_refused'
			return res.redirect "/profile"
		passport.authenticate('linkedin',  (err, user, info) ->
			session.linkedin_auth = info
			session.save()
			req.session.linkedin_auth = info
			if not err and user
				return res.redirect "/link"
			return res.redirect "/profile"
		) req, res, next


	socket.on 'session', (fn) ->
		fn session

	socket.on 'logout', (fn) ->
		session.destroy()
		fn()


	socket.on 'db', (data, fn) ->
		feed = (doc) ->
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
							feed doc
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
								feed doc
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
				foundTotal: (total) ->
					socket.emit 'parse.total', total
				completedEmail: ->
					socket.emit 'parse.mail'
				completedAllEmails: ->
					socket.emit 'parse.queueing'
				foundNewContact: ->
					socket.emit 'parse.enqueued'

			require('./parser') app, user, notifications, fn

	socket.on 'linkin', (id, fn) ->
		console.dir session
		# TODO have a check here to see when the last time the user's contacts were parsed was. People could hit the url for this by accident.
		models.User.findById id, (err, user) ->
			throw err if err
			# TODO temporary, in case this gets called and there's not logged in user
			if not user
				return fn()

			notifications =
				foundTotal: (total) ->
					socket.emit 'parse.total', total
				completedEmail: ->
					socket.emit 'parse.mail'

			require('./linker').linker app, user, session.linkedin_auth, notifications, fn

