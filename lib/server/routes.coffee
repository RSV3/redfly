module.exports = (app, route) ->
	_ = require 'underscore'
	_s = require 'underscore.string'
	moment = require 'moment'
	crypto = require './crypto'
	logic = require './logic'
	models = require './models'
	mailer = require './mail'
	mboxer = require './mboxer'

	Elastic = require './elastic'


	# when we first add a contact to ES:
	# A recently added contact may already have notes and tags,
	# so we should look for em and add em to the doc we send to ES
	primeContactForES = (doc, cb)->
		models.Note.find {contact:doc._id}, (nerr, notes)->
			models.Tag.find {contact:doc._id}, (terr, tags)->
				if not nerr and notes?.length
					doc._doc.notes = _.map notes, (n)-> {body:n.body, user:n.author}
				if not terr and tags?.length
					doc._doc.indtags = _.map _.filter(tags, (t)->t.category is 'industry'), (t)-> {body:t.body, user:t.creator}
					doc._doc.orgtags = _.map _.reject(tags, (t)->t.category is 'industry'), (t)-> {body:t.body, user:t.creator}
				cb doc

	searchPagePageSize = 10

	route 'db', (data, io, session, fn)->

		cb = (payload) ->
			root = _s.underscored data.type
			if _.isArray payload then root += 's'
			hash = {}
			hash[root] = payload
			fn hash

		model = models[data.type]

		# add details about doc into feed
		feed = (doc, type) ->
			o = {type: type, id: doc.id}
			if doc.addedBy then o.addedBy = doc.addedBy
			app.io.broadcast 'feed', o

		# this little routine updates the relevant elasticsearch document when we add or remove tags or notes
		# if incflag is set, this is an add, so increment the datacount
		runScriptOnOp = (doc, type, field, script, incflag)->
			user = doc.creator or doc.author
			if not doc.contact or not user then return
			if incflag then models.User.update {_id:user}, $inc: 'dataCount': 1, (err)->
				if err
					console.log "error incrementing data count for #{user}"
					console.dir err
				feed doc, type
			esup_doc =
				params: val: {user:String(user), body:doc.body}
				script: script
			Elastic.update String(doc.contact), esup_doc, (err)->
				if not err then return
				console.log "ERR: ES adding new #{field} #{doc.body} to #{doc.contact} from #{user}"
				console.dir doc
				console.dir err

		updateOnCreate = (doc, type, field)->
			runScriptOnOp doc, type, field, "if (ctx._source.?#{field} == empty) { ctx._source.#{field}=[val] } else if (ctx._source.#{field}.contains(val)) { ctx.op = \"none\" } else { ctx._source.#{field} += val }", true

		updateOnDelete = (doc, type, field)->
			runScriptOnOp doc, field, "if (ctx._source.?#{field} == empty) {ctx.op=\"none\"} else if (ctx._source.#{field} == val) { ctx._source.#{field} = null} else if (ctx._source.#{field}.contains(val)) { ctx._source.#{field}.remove(val) } else { ctx.op = \"none\" }"


		switch data.op
			when 'find'
				# TODO
				try
					if id = data.id
						model.findById id, (err, doc) ->
							throw err if err
							switch data.type
								when 'Admin'
									if doc
										# mongoose is cool, but we need do this to get around its protection
										if process.env.CONTEXTIO_KEY then doc._doc['contextio'] = true
										if process.env.GOOGLE_API_ID then doc._doc['googleauth'] = true
									else
										new_adm = {_id:1, domains:process.env.ORGANISATION_DOMAIN}
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
				if model is models.Contact
					if record.names?.length and not record.sortname then record.sortname = record.names[0].toLowerCase()
					if record.addedBy and not record.knows?.length then record.knows = [record.addedBy]
				model.create record, (err, doc) ->
					throw err if err
					cb doc
					switch model
						when models.Note
							updateOnCreate doc, 'Note', "notes"
						when models.Tag
							updateOnCreate doc, 'Tag', if doc.category is 'industry' then 'indtags' else 'orgtags'
						when models.Contact
							if doc.addedBy
								feed doc, data.type
								Elastic.create doc, (err)->
									if not err then return
									console.log "ERR: ES creating new contact"
									console.dir doc
									console.dir err

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
					if model is models.Contact 
						if record.added is null
							doc.set 'added', undefined
							doc.set 'classified', undefined
					modified = doc.modifiedPaths()
					# Important to do updates through the 'save' call so middleware and validators happen.
					doc.save (err) ->
						throw err if err
						cb doc
						switch model
							when models.Contact
								if doc.added
									if 'added' in modified
										feed doc, data.type
										console.log "priming contact from save"
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
								if 'classified' in modified
									models.User.update {_id:session.user}, $inc: {'contactCount':1, 'fullCount':1}, (err)->
										if err
											console.log "error incrementing data count for #{session.user}"
											console.dir err
								else if 'updated' in modified
									models.User.update {_id:session.user}, $inc: 'dataCount': 1, (err)->
										if err
											console.log "error incrementing data count for #{session.user}"
											console.dir err

			when 'remove'
				if id = data.id
					model.findByIdAndRemove id, (err, doc) ->
						throw err if err
						cb()
						if doc
							switch data.type
								when 'Contact'
									Elastic.delete id, (err)->
										if not err then return
										console.log "ERR: ES deleting #{id} on db remove"
										console.dir err
								when 'Note'
									updateOnDelete doc, 'Note', "notes"
								when 'Tag'
									updateOnDelete doc, 'Tag', if doc.category is 'industry' then 'indtags' else 'orgtags'

				else if ids = data.ids
					throw new Error 'unimplemented'	# Remove each one and call cb() when they're all done.
				else
					throw new Error 'no id on remove'
			else
				throw new Error 'un recognised db route'


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

	route 'login.contextio', (data, io, session, fn) ->
		models.User.findOne email: data.email, (err, user) ->
			if err
				console.log err
				return fn err:'email'
			if user and user.cIO
				if crypto.hashPassword(data.password, user.cIO.salt) is user.cIO.hash
					session.user = user.id
					session.save()
					return fn id:user.id
			mboxer.create data, (cIOdata)->
				console.dir cIOdata
				if not cIOdata?.success then return fn err:'email'
				if cIOdata.err then return fn err:cIOdata.err
				if not user
					console.log "creating new user #{data.email}"
					console.dir cIOdata
					user = new models.User
				user.name = data.name or data.email
				user.email = data.email
				user.cIO =
					expired:false
					user:data.name
					label:cIOdata.source.label
					salt:crypto.generateSalt()
				user.cIO.hash = crypto.hashPassword(data.password, user.cIO.salt)
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
			models.Contact.count {added:{$exists:true}, _id:{$in:tag.contacts}}, (e, c)->
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
				oIDs.push models.ObjectId(id)
			conditions.contact = $in: oIDs
		models.Tag.aggregate {$match: conditions},
			{$group:  _id: '$body', count: {$sum: 1}, contacts:$addToSet:'$contact'},
			{$sort: count: -1},
			(err, tags) ->
				throw err if err
				if ids?.length then return cb _.pluck(tags, '_id')[0..5]
				considerTags tags, cb


	# refactored search:
	# optional limit for the dynamic searchbox,
	# and a final callback where we can decide what attributes to package for returning
	doSearch = (fn, data, session, limit=0) ->
		query = data.filter or data.query or ''
		compound = _.compact query.split ':'
		if not compound.length then terms=''
		else terms = compound[compound.length-1]

		availableTypes = ['name', 'email', 'company', 'tag', 'note']
		fields = []		# this array maps the array of results to their type
		if compound.length is 1						# type specified, eg tag:slacker
			for type in availableTypes
				fields.push type
		else if compound[0] is 'contact'
			fields = ['name', 'email']
			if not data.knows then data.knows = []
			data.knows.push session.user				# limit 'contact' search to contacts we know.
		else fields = [compound[0]]

		filters = []
		if data.knows?.length then filters.push terms:knows:data.knows
		if data.industry?.length 
			thisf = []
			for tag in data.industry
				thisf.push term:"indtags.body.raw":tag,
			if data.indAND then filters.push "and":thisf
			else filters.push "or":thisf
		if data.organisation?.length 
			thisf = []
			for tag in data.organisation
				thisf.push term:"orgtags.body.raw":tag
			if data.orgAND then filters.push "and":thisf
			else filters.push "or":thisf

		sort = {}
		if data.sort
			key = data.sort
			if key[0] is '-'
				key=key.substr 1
				dir = 'desc'
			else dir = 'asc'
			if key is "names"
				key = "sortname"
				sort[key]=dir
				delete data.sort
			else if key is 'added'
				sort[key]=dir
				delete data.sort
			else
				key="#{key}.value"
				sort[key]=dir
		else if not query.length
			sort.added = 'desc'

		if not limit
			options = {limit:searchPagePageSize, facets: not data.filter, highlights: false}
			if data.page then options.skip = data.page*searchPagePageSize
		else options = {limit:limit, skip:0, facets: false, highlights: true}
		Elastic.find fields, terms, filters, sort, options, (err, totes, docs, facets) ->
			throw err if err
			resultsObj = query:query
			if docs?.length
				if facets then resultsObj.facets = facets
				if docs[0].field
					resultsObj.response = {}
					for d in docs
						if _.contains ['indtags','orgtags'], d.field then thefield = 'tags'
						else thefield = d.field
						if not resultsObj[thefield] then resultsObj[thefield] = []
						resultsObj[thefield].push {_id:d._id, fragment:d.fragment}
				else
					resultsObj.response = _.pluck docs, '_id'
					resultsObj.totalCount = resultsObj.filteredCount = totes
			return fn resultsObj


	route 'fullSearch', (data, io, session, fn) ->
		doSearch fn, data, session

	route 'search', (data, io, session, fn)->
		doSearch fn, data, session, 19


	route 'verifyUniqueness', (data, fn) ->
		field = data.field + 's'
		conditions = {}
		conditions[field] = data.value
		models.Contact.findOne conditions, (err, contact) ->
			throw err if err
			fn contact?[field][0]

	route 'getIntro', (data, fn) ->	# get an email introduction
		models.Contact.findById data.contact, (err, contact) ->
			throw err if err
			models.User.findById data.userfrom, (err, userfrom) ->
				throw err if err
				models.User.findById data.userto, (err, userto) ->
					throw err if err
					mailer.requestIntro userfrom, userto, contact, data.url, ()->
						fn()

	route 'deprecatedVerifyUniqueness', (data, fn) ->	# Deprecated, bitches
		models.Contact.findOne().ne('_id', data.id).in(data.field, data.candidates).exec (err, contact) ->
			throw err if err
			fn _.chain(contact?[data.field])
				.intersection(data.candidates)
				.first()
				.value()

	route 'tags.remove', (conditions, fn) ->
		models.Tag.find conditions, '_id', (err, ids)->
			throw err if err
			ids =  _.pluck ids, '_id'
			models.Tag.remove {_id: $in: ids}, (err)->
				if err
					console.log "error removing tags:"
					console.dir ids
					console.dir err
			fn ids

	route 'tags.all', (conditions, fn) ->
		models.Tag.find(conditions).distinct 'body', (err, bodies)->
			throw err if err
			fn bodies.sort()

	route 'tags.move', (conditions, fn) ->
		if (newcat = conditions.newcat)
			delete conditions.newcat
			models.Tag.update conditions, {category:newcat}, {multi:true}, (err) ->
				if err and err.code is 11001 then return models.Tag.remove conditions, fn
				console.dir err if err
				return fn()
		fn()

	route 'tags.rename', (conditions, fn) ->
		if (newtag = conditions.new)
			delete conditions.new
			models.Tag.update conditions, {body:newtag}, {multi:true}, (err)->
				if err and err.code is 11001 then return models.Tag.remove conditions, fn
				console.dir err if err
				return fn()
		fn()

	route 'tags.popular', (conditions, fn) ->
		if conditions.contact then conditions.contact = models.ObjectId(conditions.contact)
		else conditions.contact = $exists: true
		models.Tag.aggregate {$match: conditions},
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

	route 'merge', (data, fn) ->
		console.log ''
		console.log 'merge'
		console.dir data
		console.log ''
		updatedObject = {}
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
		models.User.findById id, (err, user) ->
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


	route 'classifyQ', (id, fn) ->
		logic.classifyList id, (neocons)->
			fn _.map neocons, (n)-> models.ObjectId(n)		# convert back to objectID

	route 'classifyCount', logic.classifyCount		# classifyCount has the same signature as the route: (id, cb)

	route 'companies', (fn)->
		oneWeekAgo = moment().subtract('days', 700).toDate()
		# TODO: fix companies
		# this is still kinda nonsense. we really wanna search mails from the last week,
		# then search all contacts in those mails, to then get their company
		models.Contact.find({company:{$exists:true}, added:{$gt:oneWeekAgo}}).execFind (err, contacts)->
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
			models.Classify.create classification, (err, mod)->
				if err
					console.log 'flush err:'
					console.log err
					console.dir mod
		fn()

	route 'recent', (fn)->
		models.Contact.find({added:{$exists:true}, picture:{$exists:true}}).sort(added:-1).limit(searchPagePageSize).execFind (err, contacts)->
			throw err if err
			recent = _.map contacts, (c)->c._id.toString()
			console.log "recent"
			console.dir recent
			fn recent

	route 'leaderboard', (fn)->
		models.User.find().select('_id contactCount dataCount lastRank').exec (err, users)->
			throw err if err
			l = users.length
			users = _.map _.sortBy(users, (u) ->
				((u.contactCount or 0) + (u.dataCount or 0)/5)*l + l - (u.lastRank or 0)
			), (u)-> String(u.get('_id'))
			fn process.env.RANK_DAY, l, users[l-5...l].reverse(), users[0...5].reverse()

