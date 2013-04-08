module.exports = (app, route) ->
	_ = require 'underscore'
	logic = require './logic'
	models = require './models'

	route 'db', (fn, data) ->
		feed = (doc) ->
			o =
				type: data.type
				id: doc.id
			if doc.addedBy then o.addedBy = doc.addedBy
			app.io.broadcast 'feed', o

		cb = (payload) ->
			root = data.type.toLowerCase()
			if _.isArray payload then root += 's'
			hash = {}
			hash[root] = payload
			fn hash
		model = models[data.type]
		switch data.op
			when 'find'
				# TODO
				try
					if id = data.id
						model.findById id, (err, doc) ->
							throw err if err
							cb doc
					else if ids = data.ids
						model.find _id: $in: ids, (err, docs) ->
							throw err if err
							docs = _.sortBy docs, (doc) ->
								ids.indexOf doc.id
							cb docs
					else if query = data.query
						if not query.conditions and not query.options
							query = conditions: query
						model.find query.conditions, null, query.options, (err, docs) ->
							throw err if err
							cb docs
					else
						model.find (err, docs) ->
							throw err if err
							cb docs
				catch err
					console.error 'Error in db API: ' + err
					cb()
			when 'create'
				record = data.record
				if not _.isArray record
					model.create record, (err, doc) ->
						throw err if err
						cb doc
						if (model is models.Contact) or (model is models.Tag) or (model is models.Note)
							feed doc
				else
					throw new Error 'unimplemented'
					# model.create record, (err, docs...) ->
					# 	throw err if err
					# 	cb docs
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
							cb doc
							if updateFeeds
								feed doc
				else
					throw new Error 'unimplemented'
			when 'remove'
				if id = data.id
					model.findByIdAndRemove id, (err) ->
						throw err if err
						cb()
				else if ids = data.ids
					throw new Error 'unimplemented'	# Remove each one and call cb() when they're all done.
				else
					throw new Error
			else
				throw new Error


	route 'summary.organisation', (fn) ->
		fn process.env.ORGANISATION_TITLE

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


	# refactored searcH:
	# optional limit for the dynamic searchbox,
	# and a final callback where we can decide what attributes to package for returning
	doSearch = (fn, data, searchMap, limit=0) ->
		if not data.query
			return []
		terms = _.uniq _.compact data.query.split(' ')
		search = {}
		availableTypes = ['name', 'email', 'tag', 'note']
		utilisedTypes = []
		for type in availableTypes
			search[type] = []
			for term in terms
				compound = _.compact term.split ':'
				if compound.length > 1
					# TODO
					#search[type].push compound[1]
					if compound[0] is type
						search[type].push compound[1]
						utilisedTypes.push type
				else
					search[type].push term
					utilisedTypes.push type
			if not search[type].length then delete search[type]
		step = require 'step'
		step ->
			if search.name and search.name.length > 1			# search on "firstname lastname"
				utilisedTypes.unshift 'name'
				reTerm = new RegExp data.query, 'i'
				models.Contact.find({names:reTerm}).exec @parallel()
			for type of search
				terms = search[type]
				if type is 'tag' or type is 'note'
					_s = require 'underscore.string'
					model = _s.capitalize type
					field = 'body'
				else
					model = 'Contact'
					field = type + 's'
				step ->
					conditions = {}
					for term in terms
						try
							reTerm = new RegExp term, 'i'	# Case-insensitive regex is inefficient and won't use a mongo index.
							if not conditions['$or'] and not conditions[field]
								conditions[field] = reTerm
							else
								nextC = {}
								if conditions[field]
									nextC[field] = conditions[field]
									conditions['$or'] = [ nextC ]
									delete conditions[field]
								nextC = {}
								nextC[field] = reTerm
								conditions['$or'].push nextC
						catch err
							continue	# User typed an invlid regular expression, just ignore it.

					if model is 'Contact'
						conditions.added = $exists: true
						_.extend conditions, data.moreConditions
					# else
					# 	for k, v of data.moreConditions
					# 		conditions['contact.' + k] = v

					models[model].find(conditions).limit(limit).exec @parallel()
					return undefined	# Step library is insane.
				, @parallel()
			return undefined	# Still insane? Yes?? Fine.
		, (err, docs...) ->
			throw err if err
			results = null
			utilisedTypes.forEach (type, index) ->
				if not _.isEmpty docs[index]
					results = searchMap type, docs[index], results
			return fn results


	route 'fullSearch', (fn, data) ->
		doSearch fn, data
		, (type, typeDocs, results=[]) ->
			_.union results, _.uniq _.map typeDocs, (d) ->
				if d.contact then String(d.contact) else String(d.id)


	# this is a pretty nifty routine,
	# but note that it will return a single duplicate for the edge case where
	# a search term matches both notes and tags corresponding to the same contact
	# there's a task for a rainy day ...
	route 'search', (fn, data) ->
		doSearch fn, data
		, (type, typeDocs, results={}) ->
			typeDocs = _.pluck _.filter(_.uniq(typeDocs, false, (d)->
					d.contact or d.id					# only one tag/note per contact
				), (doc)->								# filter to remove duplicates:
					for t of results					# go through each previous result type,
						id = String(doc.contact or doc._id)		# looking for this contact
						if _.some(results[t], (d)-> d is id)	# and if it's already there
							return false						# weed it out
					true
			), 'id'									# map to ids
			results[type] = _.union typeDocs, results[type] or []
			return results
		, 10	# limit

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
			{$limit: 20},
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
									if err?.code is 11001 then doc.remove cb
									else cb err
							, (err) ->
								cb err
					, (err) ->
						throw err if err
						merge.remove cb
				, (err) ->
					contact.save (err) ->
						throw err if err
						return fn()

	# TODO have a check here to see when the last time the user's contacts were parsed was. People could hit the url for this by accident.
	route 'parse', (fn, id, io) ->
		models.User.findById id, (err, user) ->
			throw err if err
			if not user then return fn()	# in case this gets called and there's not logged in user
			notifications =
				foundTotal: (total) ->
					io.emit 'parse.total', total
				completedEmail: ->
					io.emit 'parse.mail'
				completedAllEmails: ->
					io.emit 'parse.queueing'
				considerContact: ->
					io.emit 'parse.couldqueue'
				foundNewContact: ->
					io.emit 'parse.enqueued'
			require('./parser') user, notifications, (err, contacts) ->
				fn err

	route 'linkin', (fn, id, io, session) ->
		models.User.findById id, (err, user) ->
			throw err if err
			if not user then return fn err	# in case this gets called and there's not logged in user
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
			require('./linker') user, notifications, (err, changes) ->
				if not _.isEmpty changes then io.emit 'linked', changes
				fn err

