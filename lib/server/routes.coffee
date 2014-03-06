module.exports = (route) ->
	_ = require 'underscore'
	_s = require 'underscore.string'
	moment = require 'moment'
	Crypto = require './crypto'
	Logic = require './logic'
	Models = require './models'
	Mailer = require './mail'
	Mboxer = require './mboxer'
	Search = require './search'
	Db = require './dbroutes'
	Elastic = require './elastic'


	route 'get', 'db/:type/:op', Db.getRoutes

	route 'post', 'db/:type/:op', Db.postRoutes


	route 'get', 'dashboard', (fn)->
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

	route 'get', 'stats', (fn)->
		stats = {}
		last30days = $gt:moment().subtract('days', 30).toDate()
		query = added:last30days
		Models.Contact.count query, (err, totes)->
			if not err then stats.totalThisMonth = totes
			query.classified = $not:last30days				# avoids mongoose cast error, while matching both true and $exists:false
			Models.Contact.count query, (err, totes)->
				if not err then stats.autoThisMonth = totes
				fn stats

	route 'get', 'summary.organisation', (fn) ->
		fn process.env.ORGANISATION_TITLE

	route 'get', 'total.contacts', (fn) ->
		Logic.countConts (err, count) ->
			throw err if err
			fn count

	route 'get', 'summary.contacts', (fn) ->
		Logic.summaryContacts (err, count) ->
			throw err if err
			fn count

	route 'get', 'summary.tags', (fn) ->
		Logic.summaryTags (err, count) ->
			throw err if err
			fn count

	route 'get', 'summary.notes', (fn) ->
		Logic.summaryNotes (err, count) ->
			throw err if err
			fn count

	# do we even use this anymore?? weird. #jTNT
	route 'get', 'summary.verbose', (fn) ->
		Models.Tag.find().where('deleted').exists(false).sort('date').select('body').exec (err, tags) ->
			throw err if err
			verbose = _.max tags, (tag) ->
				tag.body.length
			fn verbose?.body

	route 'get', 'summary.user', (fn) ->
		fn 'Joe Chung'

	route 'post', 'login.contextio', (params, body, session, fn) ->
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


	route 'get', 'fullSearch', (body, session, fn) ->
		Search fn, body, session

	route 'get', 'search', (body, session, fn)->
		Search fn, body, session, 19


	route 'get', 'verifyUniqueness', (data, session, fn) ->
		field = data.field + 's'
		conditions = {}
		conditions[field] = data.value
		Models.Contact.findOne conditions, (err, contact) ->
			throw err if err
			fn contact?[field][0]

	route 'get', 'getIntro', (data, session, fn) ->	# get an email introduction
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

	route 'get', 'deprecatedVerifyUniqueness', (data, session, fn) ->
		Models.Contact.findOne().ne('_id', data.id).in(data.field, data.candidates).exec (err, contact) ->
			throw err if err
			fn _.chain(contact?[data.field])
				.intersection(data.candidates)
				.first()
				.value()

	route 'get', 'tags.stats', (fn) ->
		match = $match: deleted: $exists: false
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
		Models.Tag.aggregate match, group, project, (err, results) ->
			throw err if err
			fn results

	route 'get', 'tags.all', (conditions, session, fn) ->
		conditions.deleted = $exists:false
		Models.Tag.find(conditions).distinct 'body', (err, bodies)->
			throw err if err
			fn bodies.sort()

	route 'get', 'tags.popular', (conditions, session, fn) ->
		if conditions.contact then conditions.contact = Models.ObjectId(conditions.contact)
		else conditions.contact = $exists: true
		conditions.deleted = $exists:false
		Models.Tag.aggregate {$match: conditions},
			{$group:  _id: '$body', category: {$first:'$category'}, count: {$sum: 1}},
			{$sort: count: -1},
			{$limit: 20},
			(err, results) ->
				throw err if err
				fn _.map results, (r)-> {body:r._id, category:r.category}

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

	route 'post', 'tags.move', (conditions, session, fn) ->
		if not conditions.newcat then return fn()
		updates = category:conditions.newcat
		delete conditions.newcat
		_updateTags updates, conditions, fn

	route 'post', 'tags.rename', (conditions, session, fn) ->
		if not conditions.new then return fn()
		updates = body:conditions.new
		delete conditions.new
		_updateTags updates, conditions, fn

	# we can also rename the tag categories...
	route 'post', 'renameTags', (data, session, fn)->
		Models.Tag.update {category:data.old.toLowerCase()}, {$set:category:data.new.toLowerCase()}, {multi:true}, (err) ->
			if err then console.dir err
			fn err

	route 'post', 'tags.remove', (conditions, session, fn) ->
		Models.Tag.find conditions, (err, tags)->
			throw err if err
			ids = _.pluck tags, '_id'
			Models.Tag.remove {_id: {$in: ids}, deleted: {$exists: false}}, (err)->
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

	route 'post', 'merge', (data, session, fn) ->
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
							Db.primeContactForES contact, (doc)->
								Elastic.create doc, (err)->
									fn updatedObject
									if not err then return
									console.log "ERR: ES updating #{type}"
									console.dir doc
									console.dir err

	# TODO have a check here to see when the last time the user's contacts were parsed was. People could hit the url for this by accident.
	routing_flag_hash = {}
	route 'get', 'parse/:id', (params, body, session, fn) ->
		id = params.id
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

	route 'get', 'linkin/:id', (params, body, session, fn) ->
		Models.User.findById params.id, (err, user) ->
			throw err if err
			if not user then return fn err	# in case this gets called and there's not logged in user
			notifications = {}
			###
			# ccos we removed socket.io
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
			###
			require('./linker').linker user, notifications, (err, changes) ->
				#if not _.isEmpty changes then io.emit 'linked', changes
				fn err


	route 'get', 'classifyQ/:id', (params, body, session, fn) ->
		Logic.classifyList params.id, (neocons)->
			fn _.map neocons, (n)-> Models.ObjectId(n)		# convert back to objectID

	route 'get', 'classifyCount/:id', (params, body, session, fn) ->
		Logic.classifyCount params.id, fn

	route 'get', 'requestCount/:id', (params, body, session, fn) ->
		Logic.requestCount params.id, fn


	route 'get', 'companies', (fn)->
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


	route 'post', 'flush', (session, fn) ->
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

	route 'get', 'leaderboard', (session, fn)->
		Models.User.find().select('_id contactCount dataCount lastRank').exec (err, users)->
			throw err if err
			l = users.length
			users = _.map _.sortBy(users, (u) ->
				((u.contactCount or 0) + (u.dataCount or 0)/5)*l + l - (u.lastRank or 0)
			), (u)-> String(u.get('_id'))
			Search (results)->
				fn process.env.RANK_DAY, l, users[l-5...l].reverse(), users[0...5].reverse(), results?.totalCount
			, {moreConditions:poor:true}, session


	route 'get', 'requests', (data, session, fn) ->
		currentReqs = null
		skip = data?.skip or 0
		pageSize = 10
		if data?.old
			query = expiry:$exists:true
			if data.me then query.user = session.user
			else query.user = $ne:session.user
		else query = expiry:$exists:false
		Models.Request.find(query).sort(expiry:-1).skip(skip).limit(pageSize+1).execFind (err, reqs)->
			theresMore = reqs?.length > pageSize
			if not err and reqs?.length then currentReqs = _.map reqs[0...pageSize], (r)->r._id.toString()
			fn currentReqs, theresMore

