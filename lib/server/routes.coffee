module.exports = (app, route) ->
	_ = require 'underscore'
	moment = require 'moment'
	crypto = require './crypto'
	logic = require './logic'
	models = require './models'
	mailer = require './mail'
	mboxer = require './mboxer'

	searchPagePageSize = 25

	route 'db', (data, io, session, fn)->
		feed = (doc) ->
			o =
				type: data.type
				id: doc.id
			if doc.addedBy then o.addedBy = doc.addedBy
			app.io.broadcast 'feed', o

		cb = (payload) ->
			_s = require 'underscore.string'
			root = _s.underscored data.type
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
					if model is models.Note and doc.contact
						models.User.update {_id:doc.author}, $inc: 'dataCount': 1, (err)->
							if err
								console.log "error incrementing data count for #{doc.author}"
								console.dir err
						feed doc
					if model is models.Tag and doc.contact
						console.dir "#{doc.creator}"
						models.User.update {_id:doc.creator}, $inc: 'dataCount': 1, (err)->
							if err
								console.log "error incrementing data count for #{doc.creator}"
								console.dir err
						feed doc
					else if model is models.Contact and doc.addedBy
						feed doc

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
						if model is models.Contact 
							if 'added' in modified and doc.added then feed doc
							if 'classified' in modified
								models.User.update {_id:doc.updatedBy}, $inc: 'contactCount': 1, (err)->
									if err
										console.log "error incrementing data count for #{doc.updatedBy}"
										console.dir err
							else if 'updatedBy' in modified
								models.User.update {_id:session.user}, $inc: 'dataCount': 1, (err)->
									if err
										console.log "error incrementing data count for #{session.user}"
										console.dir err

			when 'remove'
				if id = data.id
					model.findByIdAndRemove id, (err) ->
						throw err if err
						cb()
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


	# adds filter lists on results object before returning first page
	#
	# results ;		results object (so far) including query, response and total
	# fn ;			callback function to send the data back to the client
	# termCount ;	if this flag is false, the filters are built from the entire collection
	# 				if this flag is non-zero, the filters are built against the subset of results
	buildFilters = (results, fn, termCount, step=0)->
		switch step
			when 0
				query = added:$exists:true
				if termCount then query._id = $in:results.response
				else query.knows = $not:$size:1
				models.Contact.find(query).select('knows').exec (err, contacts)->
					knows = _.countBy _.flatten(_.pluck contacts, 'knows'), (k)->k
					results.f_knows = _.sortBy(_.keys(knows), (k)->-knows[k])[0..5]
					buildFilters results, fn, termCount, 1
			when 1
				ids = if termCount then results.response else null
				loadSomeTagNames ids, 'industry', (tags)->
					results.f_industry = tags
					buildFilters results, fn, termCount, 2
			when 2
				ids = if termCount then results.response else null
				loadSomeTagNames ids, $not: $in: [ 'industry', 'organisation' ], (tags)->
					results.f_organisation = tags
					results.response = results.response[0..searchPagePageSize]			# ... first page
					fn results
		

	# filters and paginates search results using the parameters specified on the data object
	filterSearch = (session, data, results, fn, page=0)->
		if data.page
			page = data.page
			delete data.page
		if data.knows?.length
			query = {_id:{$in:results.response}, knows:{$in:data.knows}}
			delete data.knows
			return models.Contact.find(query).select('_id').exec (err, contactids)->
				contactids = _.map contactids, (t)-> String(t.get('_id'))
				if not err then results.response = _.intersection results.response, contactids
				filterSearch session, data, results, fn, page
		if data.industry?.length
			query = {contact:{$in:results.response}, category:'industry', body:{$in:data.industry}}
			delete data.industry
			return models.Tag.find(query).select('contact').exec (err, tagcontacts)->
				tagcontacts = _.map tagcontacts, (t)-> String(t.get('contact'))
				if not err then results.response = _.intersection results.response, tagcontacts
				filterSearch session, data, results, fn, page
		if data.organisation?.length
			query = {contact:{$in:results.response}, category:{$ne:'industry'}, body:{$in:data.organisation}}
			delete data.organisation
			return models.Tag.find(query).select('contact').exec (err, tagcontacts)->
				tagcontacts = _.map tagcontacts, (t)-> String(t.get('contact'))
				if not err then results.response = _.intersection results.response, tagcontacts
				filterSearch session, data, results, fn, page
		if data.sort # sort filtered objects
			query = _id:$in:results.response		# query the subset we're sorting
			dir = -1								# sort ascending
			key = data.sort							# sort term
			delete data.sort
			if key[0] is '-' then key = key.substr 1
			else dir = 1
			if key is 'names' then key = 'sortname'	# if sorting by names, only look at first instance
			sort = {}
			sort[key] = dir
			switch key
				when 'influence'
					return models.Contact.find(query).exec (err, contacts)->
						if not err
							contacts = _.sortBy contacts, (c)->c.knows.length * dir
							results.response = _.map contacts, (t)-> String(t.get('_id'))
						filterSearch session, data, results, fn, page
				when 'proximity'
					return models.Contact.find(query).exec (err, contacts)->
						if not err
							contacts = _.sortBy contacts, (c)->
								_.some c.knows, (k)-> String(k) is String(session.user)
							results.response = _.map contacts, (t)-> String(t.get('_id'))
						filterSearch session, data, results, fn, page
				else
					return models.Contact.find(query).select('_id').sort(sort).exec (err, contactids)->
						if not err then results.response = _.map contactids, (t)-> String(t.get('_id'))
						filterSearch session, data, results, fn, page

		# fall thru to pagination
		results.filteredCount = results.response.length
		results.response = results.response[page*searchPagePageSize...(page+1)*searchPagePageSize]		# finally, paginate
		fn results


	# refactored search:
	# optional limit for the dynamic searchbox,
	# and a final callback where we can decide what attributes to package for returning
	doSearch = (fn, data, session, searchMap, limit=0) ->
		if not (query = data.filter or data.query) then return []
		compound = _.compact query.split ':'
		if compound.length > 1 then terms = _.uniq _.compact compound[1].split(' ')			# type specified, eg tag:slacker
		else terms = _.uniq _.compact query.split(' ')			# multiple search terms, eg john doe
		search = {}
		availableTypes = ['name', 'email', 'tag', 'note']
		utilisedTypes = []	# this array maps the array of results to their type
		perfectMatch = []	# array of flags: a perfectmatch is a result set for the full query string,
							# other than merely one of multiple terms.
							# perfectmatches appear earlier in the results
		for type in availableTypes
			search[type] = []
			for term in terms
				if terms.length is 1 or not _.contains ['and', 'to', 'with', 'a'], term
					if compound.length > 1						# type specified, eg tag:slacker
						if compound[0] is type then search[type].push term
						if compound[0] is 'contact'
							if type is 'name' then search[type].push term
							if parseInt(term).toString() isnt term
								if type is 'email' then search[type].push term
					else										# not specified, try this term in each type
						search[type].push term
			if not search[type].length then delete search[type]
			else
				if terms.length > 1			# eg. search on "firstname lastname"
					utilisedTypes.push type
					perfectMatch.push true
				utilisedTypes.push type
				perfectMatch.push false

		step = require 'step'
		step ->
			for type of search
				sort = {}
				skip = 0
				terms = search[type]
				if type is 'tag' or type is 'note'
					_s = require 'underscore.string'
					model = _s.capitalize type
					field = 'body'
				else
					model = 'Contact'
					field = type + 's'
				conditions = {}
				if compound.length > 1 and compound[0] is 'contact'
					if parseInt(compound[1], 10).toString() is compound[1]
						limit = parseInt(compound[1], 10)
						terms = []
				if terms.length > 1			# eg. search on "firstname lastname"
					try
						conditions[field] = new RegExp _.last(compound), 'i'
					catch err
						console.log err	# probably User typed an invlid regular expression, just ignore it.
					if conditions[field]
						if model is 'Contact'
							conditions.added = $exists: true	# unclassified contacts might not be added
						else if model is 'Tag'
							conditions.contact = $exists: true	# priority tags have no contact: ignore em.
						models[model].find(conditions).exec @parallel()

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
						if not terms?.length		# special case: no terms means we're looking at all contacts
							hazFilter = true
							if data.knows?.length
								_.extend conditions, knows:$in:data.knows
								delete data.knows
							else if data.industry?.length
								conditions = category:'industry'
								conditions.body = $in:data.industry
								conditions.contact = $exists:true
								model = 'Tag'
								delete data.industry
							else if data.organisation?.length
								conditions = category:$ne:'industry'
								conditions.body = $in:data.organisation
								conditions.contact = $exists:true
								model = 'Tag'
								delete data.organisation
							else hazFilter = false
							if model is 'Contact'
								dir = -1
								if not data.sort
									key = "added"
									sort[key]=dir
								else
									key = data.sort
									if key[0] is '-' then key=key.substr 1
									else dir = 1
									if key is "names"
										key = "sortname"
										sort[key]=dir
										delete data.sort
									else if key is 'added'
										sort[key]=dir
										delete data.sort
								if not hazFilter
									limit = searchPagePageSize
									if data.page then skip = data.page*searchPagePageSize
					else if model is 'Tag'
						conditions.contact = $exists: true
					models[model].find(conditions).sort(sort).limit(limit).skip(skip).exec @parallel()
					return undefined	# Step library is insane.
				, @parallel()
			return undefined	# Still insane? Yes?? Fine.

		, (err, docs...) ->
			throw err if err
			results = null
			mapSearches = (index)->											# in order to check $exists:added
				if index is utilisedTypes.length
					# note the query parameter is returned in the results
					# to ensure that stale old results don't overwrite more recent search requests
					# that happened to respond earlier
					if not results then results = {query:query, response:null}
					else if _.isArray results
						resultsObj = query:query
						resultsObj.response = _.pluck _.sortBy(results, (r)-> -r.count), 'id'
						if not terms?.length then return models.Contact.count {added:$exists:true}, (e, c)->
							resultsObj.totalCount = resultsObj.filteredCount = c
							if not data.filter then buildFilters resultsObj, fn, terms?.length
							else if limit then fn resultsObj
							else filterSearch session, data, resultsObj, fn
						resultsObj.totalCount = resultsObj.filteredCount = resultsObj.response.length
						if data.filter then return filterSearch session, data, resultsObj, fn
						else return buildFilters resultsObj, fn, terms?.length
					else
						for type of results
							if not results[type].length then delete results[type]
							else results[type] = _.pluck results[type], 'id'
						results.query = query
					return fn results		# we need this to be async
				if _.isEmpty docs[index] then return mapSearches index+1

				done = ->
					searchMap utilisedTypes[index], perfectMatch[index], docs[index], results, (res)->
						results = res
						mapSearches index+1
				# if the results are of type other than contact, we need to check that $exists:added
				if docs[index][0].contact
					cids = _.uniq _.pluck(docs[index], 'contact'), (u)-> String(u)
					models.Contact.find({added: {$exists: true}, _id: {$in: cids}}).distinct '_id', (err, valids)->
						valids = _.map valids, (d)-> String(d)
						docs[index] = _.filter docs[index], (d)->
							_.contains(valids, String(d.contact)) and (valids = _.without valids, String(d.contact))
						done()
				else done()
			mapSearches 0

	route 'fullSearch', (data, io, session, fn) ->
		# passes a results array to accumulate a list of contact ids
		doSearch fn, data, session, (type, perfect, typeDocs, results=[], cb)->
			if not typeDocs or not typeDocs.length then return cb results
			if perfect
				matches = _.uniq _.map(typeDocs, (d)->
					count: 999											# perfect matches take priority
					id: String(d.contact or d.id)
				), (u)-> u.id
				# perfect matches replace anything already in the results list
				return cb _.union _.reject(results, (r)->_.contains _.pluck(matches, 'id'), r.id), matches
			matches = _.uniq _.map typeDocs, (d)->
				count: 0											# default
				id: String(d.contact or d.id)
			, (u)-> u.id

			# if we have too many results, or we're searching all contacts, thatsit.
			if results.length > 999 or (data.query or data.filter) is 'contact:0'
				return cb _.union results, _.reject matches, (r)-> _.contains _.pluck(results, 'id'), r.id

			###
			# this clause is used to prioritise results with more tags
			###
			ids = _.map typeDocs, (d) -> if d.contact then d.contact else d.id
			ids = _.reject ids, (r)-> _.contains _.pluck(results, 'id'), r.id
			if ids.length then models.Tag.aggregate {$match: {contact:{$in:ids}}},
				{$group:  _id: '$contact', count: $sum: 1},
				{$sort: count: -1},
				(err, aggresults) ->
					if not err and aggresults.length
						aggresults = _.map aggresults, (d)->
							return {
								id: String(d._id)
								count:d.count
							}
						results = _.union results, _.filter aggresults, (r)-> not _.contains _.pluck(results, 'id'), r.id
					# defaults won't replace anything already in the results list
					return cb _.union results, _.reject matches, (r)-> _.contains _.pluck(results, 'id'), r.id
			return results


	route 'search', (data, io, session, fn)->

		# passes an object, which accumulates arrays for each time, of the form:
		# { tag:[{contact, id}], notes:[{contact, id}], names:[{contact, id}], emails:[{contact, id}] }
		doSearch fn, data, session, (type, perfect, typeDocs, results={}, cb) ->
			if not results[type] then results[type] = []
			typeDocs = _.map typeDocs, (d)-> {id:String(d.id), contact:String(d.contact or d.id)}
			if perfect
				for t of results		# if this is a perfect match, remove duplicates from other results
					results[t] = _.filter results[t], (doc)->
						not _.some typeDocs, ((d)-> doc.contact is d.contact)
				results[type] = _.union typeDocs, results[type]
			else
				typeDocs = _.filter typeDocs, (doc)->
					for t of results		# if this is not a perfect match, remove duplicates from this result
						if results[t] and _.some results[t], ((d)-> d.contact is doc.contact)
							return false
					true
				results[type] = _.union results[type], typeDocs
			cb results
		, 10


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
	route 'parse', (id, io, fn) ->
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
			console.dir user
			fn null
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
				((u.contactCount or 0) + (u.dataCount or 0))*l + l - (u.lastRank or 0)
			), (u)-> String(u.get('_id'))
			fn l, users[l-5...l].reverse(), users[0...5].reverse()

