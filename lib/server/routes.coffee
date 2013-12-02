module.exports = (app, route) ->
	_ = require 'underscore'
	_s = require 'underscore.string'
	moment = require 'moment'
	marked = require 'marked'
	Crypto = require './crypto'
	Logic = require './logic'
	Models = require './models'
	Mailer = require './mail'
	Mboxer = require './mboxer'
	Search = require './search'
	Elastic = require './elastic'


	# when we first add a contact to ES:
	# A recently added contact may already have notes and tags,
	# so we should look for em and add em to the doc we send to ES
	primeContactForES = (doc, cb)->
		Models.Note.find {contact:doc._id}, (nerr, notes)->
			Models.Tag.find {contact:doc._id}, (terr, tags)->
				if not nerr and notes?.length
					doc._doc.notes = _.map notes, (n)-> {body:n.body, user:n.author}
				if not terr and tags?.length
					doc._doc.indtags = _.map _.filter(tags, (t)->t.category is 'industry'), (t)-> {body:t.body, user:t.creator}
					doc._doc.orgtags = _.map _.reject(tags, (t)->t.category is 'industry'), (t)-> {body:t.body, user:t.creator}
				cb doc

	route 'db', (data, io, session, fn)->

		cb = (payload) ->
			root = _s.underscored data.type
			if _.isArray payload then root += 's'
			hash = {}
			hash[root] = payload
			fn hash

		model = Models[data.type]

		# add details about doc into feed
		feed = (doc, type) ->
			o = {type: type, id: doc.id}
			if doc.addedBy then o.addedBy = doc.addedBy
			if doc.response?.length then o.response = doc.response
			app.io.broadcast 'feed', o


		switch data.op
			when 'find'
				# TODO
				try
					if id = data.id
						model.findById id, (err, doc) ->
							throw err if err
							if data.type is 'Admin'
								process.env.ORGANISTION_DOMAINS ?= process.env.ORGANISATION_DOMAIN
								process.env.AUTH_DOMAINS ?= process.env.AUTH_DOMAIN
								if doc
									# mongoose is cool, but we need do this to get around its protection
									if process.env.CONTEXTIO_KEY then doc._doc['contextio'] = true
									if process.env.GOOGLE_API_ID then doc._doc['googleauth'] = true
									if not doc.orgtagcats then doc._doc['orgtagcats'] = process.env.ORG_TAG_CATEGORIES
								else
									new_adm =
										_id: 1
										orgtagcats: process.env.ORG_TAG_CATEGORIES
										domains: process.env.ORGANISATION_DOMAINS.split /[\s*,]/
										authdomains: process.env.AUTH_DOMAINS.split /[\s*,]/
									return model.create new_adm, (err, doc) ->
										throw err if err
										if process.env.CONTEXTIO_KEY then doc._doc['contextio'] = true
										if process.env.GOOGLE_API_ID then doc._doc['googleauth'] = true
										cb doc
							cb doc
					else if ids = data.ids
						if not ids.length then return cb []
						model.find _id: $in: ids, (err, docs) ->
							throw err if err
							docs = _.sortBy docs, (doc) ->
								ids.indexOf doc.id
							cb docs
					else
						schemas = require '../schemas'
						if schemas[data.type].base
							data.query ?= conditions: {}
							data.query.conditions._type = data.type
						if query = data.query
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
				if _.isArray record then throw new Error 'unimplemented'
				switch model
					when Models.Contact
						if record.names?.length and not record.sortname then record.sortname = record.names[0].toLowerCase()
						if record.addedBy and not record.knows?.length then record.knows = [record.addedBy]
					when Models.Note
						record.body = marked record.body
				model.create record, (err, doc) ->
					if err
						console.log "ERROR: creating record"
						console.dir err
						console.dir record
						throw err unless err.code is 11000		# duplicate key
						doc = record
					cb doc
					switch model
						when Models.Note
							Elastic.onCreate doc, 'Note', "notes", (err)->
								if err then console.dir err
						when Models.Tag
							Elastic.onCreate doc, 'Tag', (if doc.category is 'industry' then 'indtags' else 'orgtags'), (err)->
								if not err then Models.User.update {_id:session.user}, $inc: 'dataCount': 1, (err)->
									if err
										console.log "error incrementing data count for #{user}"
										console.dir err
									feed doc, data.type
						when Models.Contact
							if doc.addedBy
								feed doc, data.type
								Elastic.create doc, (err)->
									if err
										console.log "ERR: ES creating new contact"
										console.dir doc
										console.dir err
						when Models.Request
							feed doc, data.type

			when 'save'
				record = data.record
				if _.isArray record then throw new Error 'unimplemented'
				model.findById record.id, (err, doc) ->
					throw err if err
					if not doc
						console.log "ERROR: failed to find record to save:"
						console.dir data
						return cb null
					_.extend doc, record
					modified = doc.modifiedPaths()
					switch model
						when Models.Contact 
							if record.added is null
								doc.set 'added', undefined
								doc.set 'classified', undefined
						when Models.Request
							if 'response' in modified		# keeping track of new response for req/res mail task
								doc.set 'updated', new Date()

					# Important to do updates through the 'save' call so middleware and validators happen.
					doc.save (err) ->
						throw err if err
						cb doc
						switch model
							when Models.Request
								if 'response' in modified		# want to make sure new responses get updated on the page
									feed doc, data.type
							when Models.Contact
								if doc.added
									if 'added' in modified
										feed doc, data.type
										primeContactForES doc, (doc)->
											Elastic.create doc, (err)->
												if not err then return
												console.log "ERR: ES updating #{type}"
												console.dir doc
												console.dir err
									else
										Elastic.update String(doc._id), doc:doc, (err)->
											if not err then return
											console.log "ERR: ES updating #{type}"
											console.dir doc
											console.dir err
								else if 'knows' in modified		# taken ourselves out of knows list?
									if not doc.knows.length
										Elastic.delete doc._id, (err)->
											if not err then return
											console.log "ERR: ES removing #{type}"
											console.dir doc
									else
										Elastic.update String(doc._id), doc:doc, (err)->
											if not err then return
											console.log "ERR: ES updating #{type}"
											console.dir doc
											console.dir err
								if 'classified' in modified
									Models.User.update {_id:session.user}, $inc: {'contactCount':1, 'fullCount':1}, (err)->
										if err
											console.log "error incrementing data count for #{session.user}"
											console.dir err
								else if 'updated' in modified
									Models.User.update {_id:session.user}, $inc: 'dataCount': 1, (err)->
										if err
											console.log "error incrementing data count for #{session.user}"
											console.dir err

			when 'remove'
				if id = data.id
					model.findByIdAndRemove id, (err, doc) ->
						throw err if err
						if not doc then return cb()
						switch data.type
							when 'Contact'
								Elastic.delete id, (err)->
									if err
										console.log "ERR: ES deleting #{id} on db remove"
										console.dir err
									cb()
							when 'Note'
								Elastic.onDelete doc, 'Note', "notes", (err)-> cb()
							when 'Tag'
								Elastic.onDelete doc, 'Tag', (if doc.category is 'industry' then 'indtags' else 'orgtags'), cb
							else cb()

				else if ids = data.ids
					throw new Error 'unimplemented'	# Remove each one and call cb() when they're all done.
				else
					throw new Error 'no id on remove'
			else
				throw new Error 'un recognised db route'


	route 'dashboard', (fn)->
		dash =
			clicks: 0
			tags: 0
			classify: 0
			users: 0
			searches: 0
			requests: 0
			responses: 0
			org: []
		Logic.recentOrgs (err, orgs)->
			if not err then dash.org = orgs
			Logic.summaryTags (err, c)->
				if not err then dash.tags = c
				Logic.summaryReqs (err, c)->
					if not err then dash.requests = c
					Logic.summaryResps (err, c)->
						if not err then dash.responses = c
						Logic.summaryUnclassified (err, c)->
							if not err then dash.classify = c
							Logic.summaryIntros (err, c)->
								if not err then dash.intros = c
								Logic.summaryActive (err, c)->
									if not err then dash.active = c
									Logic.searchCount (err, c)->
										if not err then dash.searches = c
										fn dash

	route 'stats', (fn)->
		stats = {}
		last30days = $gt:moment().subtract('days', 30).toDate()
		query = added:last30days
		Models.Contact.count query, (err, totes)->
			if not err then stats.totalThisMonth = totes query.classified = $not:last30days				# avoids mongoose cast error, while matching both true and $exists:false
			Models.Contact.count query, (err, totes)->
				if not err then stats.autoThisMonth = totes
				fn stats

	route 'summary.organisation', (fn) ->
		fn process.env.ORGANISATION_TITLE

	route 'total.contacts', (fn) ->
		Logic.countConts (err, count) ->
			throw err if err
			fn count

	route 'summary.contacts', (fn) ->
		Logic.summaryContacts (err, count) ->
			throw err if err
			fn count

	route 'summary.tags', (fn) ->
		Logic.summaryTags (err, count) ->
			throw err if err
			fn count

	route 'summary.notes', (fn) ->
		Logic.summaryNotes (err, count) ->
			throw err if err
			fn count

	route 'summary.verbose', (fn) ->
		Models.Tag.find().sort('date').select('body').exec (err, tags) ->
			throw err if err
			verbose = _.max tags, (tag) ->
				tag.body.length
			fn verbose?.body

	route 'summary.user', (fn) ->
		fn 'Joe Chung'

	route 'login.contextio', (data, io, session, fn) ->
		Models.User.findOne email: data.email, (err, user) ->
			if err
				console.log err
				return fn err:'email'
			if user and user.cIO
				if Crypto.hashPassword(data.password, user.cIO.salt) is user.cIO.hash
					session.user = user.id
					session.save()
					return fn id:user.id
			Mboxer.create data, (cIOdata)->
				console.dir cIOdata
				if not cIOdata?.success then return fn err:'email'
				if cIOdata.err then return fn err:cIOdata.err
				if not user
					console.log "creating new user #{data.email}"
					console.dir cIOdata
					user = new Models.User
				user.name = data.name or data.email
				user.email = data.email
				user.cIO =
					expired:false
					user:data.name
					label:cIOdata.source.label
					salt:Crypto.generateSalt()
				user.cIO.hash = Crypto.hashPassword(data.password, user.cIO.salt)
				user.save (err, u) ->
					if err or not u then console.dir err
					else
						session.user = u.id
						session.save()
						fn id:u.id



	# this helper goes through a list of tag aggregate candidates,
	# picking the first five which have one valid contact in its list
	# candidates: from loadSomeTagNames. _id is the body, contacts is the array of contact IDs
	_considerHash = {}
	considerTags = (candidates, cb, goodtags=[])->
		if not candidates?.length then return cb goodtags
		if goodtags.length is 5 then return cb goodtags
		if tag = candidates.shift()
			if _considerHash[tag._id]
				goodtags.push tag._id
				return considerTags candidates, cb, goodtags
			Models.Contact.count {added:{$exists:true}, _id:{$in:tag.contacts}}, (e, c)->
				if (not e) and c
					_considerHash[tag._id]=true
					goodtags.push tag._id
				return considerTags candidates, cb, goodtags

	# helper, used when building filters: get most common tags matching conditions
	loadSomeTagNames = (ids, cat, cb)->
		conditions = category:cat
		if ids?.length
			oIDs = []
			for id in ids
				oIDs.push Models.ObjectId(id)
			conditions.contact = $in: oIDs
		Models.Tag.aggregate {$match: conditions},
			{$group:  _id: '$body', count: {$sum: 1}, contacts:$addToSet:'$contact'},
			{$sort: count: -1},
			(err, tags) ->
				throw err if err
				if ids?.length then return cb _.pluck(tags, '_id')[0..5]
				considerTags tags, cb

	route 'fullSearch', (data, io, session, fn) ->
		Search fn, data, session

	route 'search', (data, io, session, fn)->
		Search fn, data, session, 19


	route 'verifyUniqueness', (data, fn) ->
		field = data.field + 's'
		conditions = {}
		conditions[field] = data.value
		Models.Contact.findOne conditions, (err, contact) ->
			throw err if err
			fn contact?[field][0]

	route 'getIntro', (data, fn) ->	# get an email introduction
		Models.Contact.findById data.contact, (err, contact) ->
			throw err if err
			Models.User.findById data.userfrom, (err, userfrom) ->
				throw err if err
				Models.User.findById data.userto, (err, userto) ->
					throw err if err
					Mailer.requestIntro userfrom, userto, contact, data.url, ()->
						intromail = {sender:userfrom, recipient:userto, contact:contact}
						Models.IntroMail.create intromail, (err, mod)->
							throw err if err
							fn()

	route 'deprecatedVerifyUniqueness', (data, fn) ->	# Deprecated, bitches
		Models.Contact.findOne().ne('_id', data.id).in(data.field, data.candidates).exec (err, contact) ->
			throw err if err
			fn _.chain(contact?[data.field])
				.intersection(data.candidates)
				.first()
				.value()

	route 'tags.remove', (conditions, fn) ->
		Models.Tag.find conditions, (err, tags)->
			throw err if err
			ids = _.pluck tags, '_id'
			Models.Tag.remove {_id: $in: ids}, (err)->
				if err
					console.log "error removing tags:"
					console.dir ids
					console.dir err
					fn null
				else
					whichtags = if conditions.category is 'industry' then 'indtags' else 'orgtags'
					bulkESupd = (tags)->
						if not tags?.length then return
						if not (tag = tags.pop()) then return bulkESupd tags
						Elastic.onDelete tag, 'Tag', whichtags, (err)->
							bulkESupd tags
					bulkESupd tags
					fn ids

	route 'tags.all', (conditions, fn) ->
		Models.Tag.find(conditions).distinct 'body', (err, bodies)->
			throw err if err
			fn bodies.sort()

	_updateTags = (updates, conditions, fn)->
		Models.Tag.find conditions, (err, tags)->
			if err or not tags?.length then return fn()
			newcat = updates.category or conditions.category
			newbod = updates.body or conditions.body
			_.each tags, (doc)->
				if conditions.category is newcat or conditions.category is 'industry' or newcat is 'industry'
					Elastic.onDelete doc, 'Tag', (if conditions.category is 'industry' then 'indtags' else 'orgtags'), (err)->
						doc.body = newbod
						Elastic.onCreate doc, 'Tag', (if newcat is 'industry' then 'indtags' else 'orgtags')
			Models.Tag.update conditions, updates, {multi:true}, (err) ->
				if err and err.code is 11001 then return Models.Tag.remove conditions, fn	# error: duplicate
				console.dir err if err
				return fn()

	route 'tags.move', (conditions, fn) ->
		if not conditions.newcat then return fn()
		updates = category:conditions.newcat
		delete conditions.newcat
		_updateTags updates, conditions, fn

	route 'tags.rename', (conditions, fn) ->
		if not conditions.new then return fn()
		updates = body:conditions.new
		delete conditions.new
		_updateTags updates, conditions, fn

	route 'tags.popular', (conditions, fn) ->
		if conditions.contact then conditions.contact = Models.ObjectId(conditions.contact)
		else conditions.contact = $exists: true
		Models.Tag.aggregate {$match: conditions},
			{$group:  _id: '$body', category: {$first:'$category'}, count: {$sum: 1}},
			{$sort: count: -1},
			{$limit: 20},
			(err, results) ->
				throw err if err
				fn _.map results, (r)-> {body:r._id, category:r.category}

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
		Models.Tag.aggregate group, project, (err, results) ->
			throw err if err
			fn results
		# fn [
		# 	{body: 'capitalism', count: 56, mostRecent: new Date()}
		# 	{body: 'communism', count: 4, mostRecent: require('moment')().subtract('days', 7).toDate()}
		# 	{body: 'socialism', count: 110, mostRecent: require('moment')().subtract('days', 40).toDate()}
		# 	{body: 'fascism', count: 61, mostRecent: require('moment')().subtract('days', 40).toDate()}
		# 	{body: 'vegetarianism', count: 5, mostRecent: require('moment')().subtract('days', 40).toDate()}
		# ]

	route 'merge', (data, fn) ->
		console.log ''
		console.log 'merge'
		console.dir data
		console.log ''
		updatedObject = {}
		Models.Contact.findById data.contactId, (err, contact) ->
			throw err if err
			Models.Contact.find().in('_id', data.mergeIds).exec (err, merges) ->
				throw err if err
				history = new Models.Merge
				history.contacts = [contact].concat merges...
				history.save (err) ->
					throw err if err

					async = require 'async'
					async.forEach merges, (merge, cb) ->
						for field in ['names', 'emails', 'knows']
							contact[field].addToSet merge[field]...
							updatedObject[field] = contact[field]
						for field in ['picture', 'position', 'company', 'yearsExperience', 'isVip', 'linkedin', 'twitter', 'facebook', 'added', 'addedBy']
							if (value = merge[field]) and not contact[field]
								contact[field] = value
								updatedObject[field] = value
						updateModels = ['Tag', 'Note', {Mail: 'recipient'}, 'Measurement', 'Classify', 'Exclude']
						async.forEach updateModels, (update, cb) ->
							conditions = {}
							if not _.isObject update then update = {type:update, field:'contact'}
							else for own key, value of update
								update.type = key
								update.field = value
							conditions[update.field] = merge.id
							Models[update.type].find conditions, (err, docs) ->
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
							Elastic.delete merge._id, (err)->
								if not err then return
								console.log "ERR: ES deleting #{merge._id} on merge"
								console.dir err
							merge.remove cb
					, (err) ->
						throw err if err
						contact?.save (err) ->
							throw err if err
							console.log "priming contact from merge"
							primeContactForES contact, (doc)->
								Elastic.create doc, (err)->
									fn updatedObject
									if not err then return
									console.log "ERR: ES updating #{type}"
									console.dir doc
									console.dir err

	# TODO have a check here to see when the last time the user's contacts were parsed was. People could hit the url for this by accident.
	routing_flag_hash = {}
	route 'parse', (id, io, fn) ->
		Models.User.findById id, (err, user) ->
			throw err if err
			if not user then return fn()	# in case this gets called and there's not logged in user
			if routing_flag_hash[id] then return	# in case this gets called twice in a row ...
			routing_flag_hash[id] = true
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
				delete routing_flag_hash[id]	# good job well done.
				fn err

	route 'linkin', (id, io, session, fn) ->
		Models.User.findById id, (err, user) ->
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
					io.broadcast 'feed',
						type: 'linkedin'
						id: contact.id
						updater: user.id
			require('./linker') user, notifications, (err, changes) ->
				if not _.isEmpty changes then io.emit 'linked', changes
				fn err


	route 'classifyQ', (id, fn) ->
		Logic.classifyList id, (neocons)->
			fn _.map neocons, (n)-> Models.ObjectId(n)		# convert back to objectID

	route 'classifyCount', Logic.classifyCount		# classifyCount has the same signature as the route: (id, cb)
	route 'requestCount', Logic.requestCount		# ditto


	route 'companies', (fn)->
		oneWeekAgo = moment().subtract('days', 700).toDate()
		# TODO: fix companies
		# this is still kinda nonsense. we really wanna search mails from the last week,
		# then search all contacts in those mails, to then get their company
		Models.Contact.find({company:{$exists:true}, added:{$gt:oneWeekAgo}}).execFind (err, contacts)->
			throw err if err
			companies = []
			_.each contacts, (contact)->
				companies.push contact.company
			companies =  _.countBy(companies, (c)->c)
			comps = []
			for c of companies
				if not c.match(new RegExp(process.env.ORGANISATION_TITLE, 'i'))
					comps.push { company:c, count:companies[c] }
			companies = _.sortBy(comps, (c)-> -c.count)[0...20]
			fn companies


	route 'flush', (contacts, io, session, fn) ->
		_.each contacts, (c)->
			classification = {user:session.user, contact:c}
			if session?.admin?.flushsave then classification.saved = moment().toDate()
			Models.Classify.create classification, (err, mod)->
				if err
					console.log 'flush err:'
					console.log err
					console.dir mod
		fn()

	###
	route 'recent', (fn)->
		Models.Contact.find({added:{$exists:true}, picture:{$exists:true}}).sort(added:-1).limit(searchPagePageSize).execFind (err, contacts)->
			throw err if err
			recent = _.map contacts, (c)->c._id.toString()
			console.log "recent"
			console.dir recent
			fn recent
	###

	route 'leaderboard', (data, io, session, fn)->
		Models.User.find().select('_id contactCount dataCount lastRank').exec (err, users)->
			throw err if err
			l = users.length
			users = _.map _.sortBy(users, (u) ->
				((u.contactCount or 0) + (u.dataCount or 0)/5)*l + l - (u.lastRank or 0)
			), (u)-> String(u.get('_id'))
			Search (results)->
				fn process.env.RANK_DAY, l, users[l-5...l].reverse(), users[0...5].reverse(), results?.totalCount
			, {moreConditions:poor:true}, session


	route 'requests', (data, io, session, fn) ->
		currentReqs = null
		skip = data?.skip or 0
		pageSize = 10
		if data?.old
			query = expiry:$lt:moment().toDate()
			if data.me then query.user = session.user
			else query.user = $ne:session.user
		else query = expiry:$gte:moment().toDate()
		Models.Request.find(query).sort(date:-1).skip(skip).limit(pageSize+1).execFind (err, reqs)->
			theresMore = reqs?.length > pageSize
			if not err and reqs?.length then currentReqs = _.map reqs[0...pageSize], (r)->r._id.toString()
			fn currentReqs, theresMore

	route 'renameTags', (data, io, session, fn)->
		Models.Tag.update {category:data.old.toLowerCase()}, {$set:category:data.new.toLowerCase()}, {multi:true}, (err) ->
			if err then console.dir err
			fn err
