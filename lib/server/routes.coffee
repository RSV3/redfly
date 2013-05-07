module.exports = (app, route) ->
	_ = require 'underscore'
	logic = require './logic'
	models = require './models'
	moment = require 'moment'


	tmStmp = (id)-> parseInt id.toString().slice(0,8), 16


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
						if model is models.Contact or model is models.Note or model is models.Tag and doc.contact
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


	route 'dashboard', (fn)->
		fn {
			clicks: 3
			tags: 4
			classify: 6
			users: 5
			searches: 3
			requests: 4
			responses: 6
			org: [
				{name: 'test.com', count: 3}
				{name: 'test2.org', count: 2}
			]}

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
	doSearch = (fn, data, session, searchMap, limit=0) ->
		if not data.query
			return []
		compound = _.compact data.query.split ':'
		if compound.length > 1						# type specified, eg tag:slacker
			terms = _.uniq _.compact compound[1].split(' ')
		else terms = _.uniq _.compact data.query.split(' ')
		search = {}
		availableTypes = ['name', 'email', 'tag', 'note']
		utilisedTypes = []
		for type in availableTypes
			search[type] = []
			for term in terms
				if terms.length is 1 or not _.contains ['and', 'to', 'with', 'a'], term
					if compound.length > 1						# type specified, eg tag:slacker
						if compound[0] is type or compound[0] is 'contact' and (type is 'name' or type is 'email')
							search[type].push term
					else										# not specified, try this term in each type
						search[type].push term
			if not search[type].length then delete search[type]
			else utilisedTypes.push type

		step = require 'step'
		step ->
			###
			if search.name and search.name.length > 1			# search on "firstname lastname"
				utilisedTypes.unshift 'name'
				reTerm = new RegExp data.query, 'i'
				models.Contact.find({names:reTerm}).exec @parallel()
			###
			for type of search
				conditions = {}
				if type is 'tag' or type is 'note'
					_s = require 'underscore.string'
					model = _s.capitalize type
					field = 'body'
				else
					model = 'Contact'
					field = type + 's'
				if compound.length > 1 and compound[0] is 'contact'
					conditions.knows = session.user
				if search[type].length > 1			# eg. search on "firstname lastname"
					utilisedTypes.unshift type
					conditions[field] = new RegExp compound[1], 'i'
					if model is 'Contact'
						conditions.added = $exists: true
					models[model].find(conditions).exec @parallel()

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
					#	_.extend conditions, data.moreConditions		# jTNT ??? wtf?
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
			mapSearches = (index)->											# in order to check $exists:added
				if index > utilisedTypes.length then return fn results		# we need this to be async
				if _.isEmpty docs[index] then return mapSearches index+1
				type = utilisedTypes[index]
				searchMap type, docs[index], results, (res)->	# note also that results can be an obj or array
					results = res
					mapSearches index+1
			mapSearches 0


	route 'fullSearch', (fn, data, io, session) ->
		doSearch fn, data, session
		, (type, typeDocs, results=[], cb) ->
			cb _.union results, _.uniq _.map typeDocs, (d) ->
				if d.contact then String(d.contact) else String(d.id)


	# this is a pretty nifty routine,
	# but note that it will return a single duplicate for the edge case where
	# a search term matches both notes and tags corresponding to the same contact
	# there's a task for a rainy day ...
	route 'search', (fn, data, io, session) ->

		# this async filter is required to confirm the $exists:added status of notes and tags
		validSearch = (type, typeDocs, results)->
			typeDocs = _.pluck _.filter(_.uniq(typeDocs, false, (d)->
					String(d.contact or d.id)			# only one tag/note per contact
				), (doc)->								# filter to remove duplicates:
					for t of results					# go through each previous result type,
						id = String(doc.contact or doc.id)		# looking for this contact
						if _.some(results[t], (d)-> d is id)	# and if it's already there
							return false						# weed it out
					true
			), 'id'									# map to ids
			results[type] = _.union typeDocs, results[type] or []
			return results

		doSearch fn, data, session
		, (type, typeDocs, results={}, cb) ->
			# if the results are of type other than contact, we need to check that $exists:added
			if typeDocs and typeDocs.length and typeDocs[0].contact
				cids = _.pluck typeDocs, 'contact'
				models.Contact.find({added: {$exists: true}, _id: {$in: cids}}).distinct '_id', (err, validcids)->
					validcids = _.map validcids, (d)-> String(d)
					typeDocs = _.filter typeDocs, (d)-> _.contains validcids, String(d.contact)
					cb validSearch type, typeDocs, results
			else 
					cb validSearch type, typeDocs, results
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

	###
	route 'tags.priority', (fn, conditions) ->
		conditions = _.extend conditions, {contact:{$exists:false}, user:{$exists:false}}
		models.Tag.find(conditions).sort({_id:-1}).limit(20).exec (err, bodies) ->
			throw err if err
			fn _.pluck(bodies, 'body').sort()
	###

	route 'tags.remove', (fn, conditions) ->
		models.Tag.find conditions, '_id', (err, ids)->
			throw err if err
			ids =  _.pluck ids, '_id'
			models.Tag.remove {_id: $in: ids}, (err)->
				if err
					console.log "error removing tags:"
					console.dir ids
					console.dir err
			fn ids

	route 'tags.all', (fn, conditions) ->
		models.Tag.find(conditions).distinct 'body', (err, bodies)->
			throw err if err
			fn bodies.sort()

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
					for field in ['picture', 'added', 'addedBy', 'position', 'company', 'yearsExperience', 'isVip', 'linkedin', 'twitter', 'facebook']
						if (value = merge[field]) and not contact[field]
							contact[field] = value
					updateModels = ['Tag', 'Note', {Mail: 'recipient'}, 'Measurement', 'Classify', 'Exclude']
					async.forEach updateModels, (update, cb) ->
						conditions = {}
						if not _.isObject update then update = {type:update, field:'contact'}
						else for own key, value of update
							update.type = key
							update.field = value
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
					io.emit 'feed',
						type: 'linkedin'
						id: contact.id
						updater: user.id
			require('./linker') user, notifications, (err, changes) ->
				if not _.isEmpty changes then io.emit 'linked', changes
				fn err

	route 'classifyQ', (fn, id) ->
		# for power users, there'll eventually be a large number of excludes
		# whereas with an aggressive classification policy there'll never be too many unclassified contacts per user
		# so first get the list of new contacts, then the subset of those who are excluded
		lastMonth = moment().subtract('months', 1)
		models.Mail.find({sender:id, sent: $gt: lastMonth}).select('recipient added sent').exec (err, msgs) ->
			throw err if err
			# every recent recipient is a candidate for the queue
			neocons = _.uniq _.map msgs, (m)->m.recipient.toString()

			# first strip out those who are permanently excluded
			models.Exclude.find(user:id, contact:$in:neocons).select('contact').exec (err, ludes) ->
				throw err if err
				neocons =  _.difference neocons, _.map ludes, (l)->l.contact.toString()

				# then strip out those which we've classified
				# (cron job will clear these out after a month, so that data doesn't go stale)
				models.Classify.find(user:id, saved:true, contact:$in:neocons).select('contact').exec (err, saves) ->
					throw err if err
					neocons =  _.difference neocons, _.map saves, (s)->s.contact.toString()

					# finally, most difficult filter: the (temporary) skips.
					# skips are classified records that dont have the 'saved' flag set.
					models.Classify.find(user:id, saved:{$exists:false}, contact:$in:neocons).select('contact').exec (err, skips) ->
						throw err if err
						skips = _.filter skips, (skip)->	# skips only count for messages prior to the skip
							not _.some msgs, (msg)->
								msg.recipient.toString() is skip.contact.toString() and tmStmp(msg._id) > tmStmp(skip._id)
						neocons = _.difference neocons, _.map skips, (k)->k.contact.toString()

						fn  _.map neocons, (n)-> models.ObjectId(n)		# convert back to objectID

	route 'flush', (fn, contacts, io, session) ->
		_.each contacts, (c)->
			classification = user: session.user, contact: c # , saved: session.admin.flushsave
			models.Classify.create classification, (err, mod)->
				if err
					console.log 'flush err:'
					console.log err
					console.dir mod
		fn()

