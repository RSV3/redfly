module.exports = (app, route) ->
	_ = require 'underscore'
	logic = require './logic'
	models = require './models'


	route 'db', (fn, data) ->
		feed = (doc) ->
			app.io.broadcast 'feed',
				type: data.type
				id: doc.id

		model = models[data.type]
		switch data.op
			when 'find'
				# TODO
				try
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
				catch err
					console.error 'Error in db API: ' + err
					return fn()
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
						updateFeeds = (model is models.Contact) and ('added' in doc.modifiedPaths())
						# Important to do updates through the 'save' call so middleware and validators happen.
						doc.save (err) ->
							throw err if err
							fn doc
							if updateFeeds
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


	route 'summary.contacts', (fn) ->
		logic.summaryContacts (err, count) ->
			throw err if err
			fn count

	route 'summary.tags', (fn) ->
		logic.summaryTags (err, count) ->
			throw err if err
			fn count

	route 'summary.notes', (fn) ->
		logic.summaryNotes (err, count) ->
			throw err if err
			fn count

	route 'summary.verbose', (fn) ->
		models.Tag.find().sort('date').select('body').exec (err, tags) ->
			throw err if err
			verbose = _.max tags, (tag) ->
				tag.body.length
			fn verbose?.body

	route 'summary.user', (fn) ->
		fn 'Joe Chung'


	route 'search', (fn, data) ->
		terms = _.uniq _.compact data.query.split(' ')
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
					_s = require 'underscore.string'
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
							_.extend conditions, data.moreConditions
						# else
						# 	for k, v of data.moreConditions
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

	route 'verifyUniqueness', (fn, data) ->
		field = data.field + 's'
		conditions = {}
		conditions[field] = data.value
		models.Contact.findOne conditions, (err, contact) ->
			throw err if err
			fn contact?[field][0]

	route 'deprecatedVerifyUniqueness', (fn, data) ->	# Deprecated, bitches
		models.Contact.findOne().ne('_id', data.id).in(data.field, data.candidates).exec (err, contact) ->
			throw err if err
			fn _.chain(contact?[data.field])
				.intersection(data.candidates)
				.first()
				.value()

	route 'tags.all', (fn, conditions) ->
		models.Tag.find(conditions).distinct 'body', (err, bodies) ->
			throw err if err
			fn bodies

	route 'tags.popular', (fn, conditions) ->
		models.Tag.aggregate {$match: conditions},
			{$group:  _id: '$body', count: $sum: 1},
			{$sort: count: -1},
			{$project: _id: 0, body: '$_id'},
			{$limit: 12},
			(err, results) ->
				throw err if err
				fn _.pluck results, 'body'

	route 'tags.stats', (fn) ->
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

	route 'merge', (fn, data) ->
		models.Contact.findById data.contactId, (err, contact) ->
			throw err if err
			models.Contact.find().in('_id', data.mergeIds).exec (err, merges) ->
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

	route 'parse', (fn, id, io) ->
		# TODO have a check here to see when the last time the user's contacts were parsed was. People could hit the url for this by accident.
		models.User.findById id, (err, user) ->
			throw err if err
			# temporary, in case this gets called and there's not logged in user
			if not user
				return fn()

			notifications =
				foundTotal: (total) ->
					io.emit 'parse.total', total
				completedEmail: ->
					io.emit 'parse.mail'
				completedAllEmails: ->
					io.emit 'parse.queueing'
				foundNewContact: ->
					io.emit 'parse.enqueued'

			require('./parser') user, notifications, fn

	route 'linkin', (fn, id, io, session) ->
		models.User.findById id, (err, user) ->
			throw err if err
			# temporary, in case this gets called and there's not logged in user
			if not user
				return fn(err)

			notifications =
				foundTotal: (total) ->
					io.emit 'link.total', total
				completedLinkedin: ->
					io.emit 'link.linkedin'
				completedContact: ->
					io.emit 'link.contact'
				updateFeeds: (contact) ->
					io.emit 'feed'
						type: 'linkedin'
						id: contact.id
						updater: user.id

			require('./linker').linker user, session.linkedinAuth, notifications, (err, changes) ->
				if not _.isEmpty changes
					io.emit 'linked', changes
				fn(err)

