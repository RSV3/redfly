moment = require 'moment'
_ = require 'underscore'

Models = require './models'
Search = require './search'

lastWeek = moment().subtract('days', 7).toDate()
lastMonth = moment().subtract('months', 1)


recentConts = (cb)->
	Search (results)->
		rcs = []
		Models.Contact.find(_id: $in: results.response).execFind (err, contacts)->
			_.each contacts, (contact)->
				pos = ""
				if contact.position
					pos += "#{contact.position} "
				if contact.company
					pos += "at #{contact.company}"
				if not (name = _.first(contact.names))
					email = _.first(contact.emails)
					splitted = email.split '@'
					domain = _.first _.last(splitted).split('.')
					name = _.first(splitted) + ' [' + domain + ']'
				rcs.push
					name: name
					picture: contact.picture or 'http://media.zenfs.com/289/2011/07/30/movies-person-placeholder-310x310_160642.png'
					position: pos
					link: '/contact/'+contact._id
			cb null, rcs
	, {}


recentOrgs = (cb)->
	Models.Contact.where('added').gt(lastWeek).execFind (err, contacts)->
		if err then return cb err, contacts
		companies = []
		_.each contacts, (contact)->
			if contact.company then companies.push contact.company
		companies =  _.countBy(companies, (c)->c)
		comps = []
		for c of companies
			if not c.match(new RegExp(process.env.ORGANISATION_TITLE, 'i'))
				comps.push { company:c, count:companies[c] }
		return cb null, _.sortBy(comps, (c)-> -c.count)[0..3]


# given a list of contacts (straight ID strings)
# 1. remove excludes
# 2. remove classifies with a date (ie already classified this month)
# 3. remove classifies without a date (ie skip this week)
# returning a (possibly shorter) list of contacts (straight ID strings)
stripSome = (u, msgs, contactsList, cb)->
	unless contactsList.length then return cb contactsList

	# first strip out those who are permanently excluded
	Models.Exclude.find(user:u, contact:$in:contactsList).select('contact').exec (err, ludes) ->
		throw err if err
		if ludes?.length
			ludes = _.map ludes, (l)->l.contact.toString()
			contactsList = _.difference contactsList, ludes
			unless contactsList.length then return cb contactsList

		# then strip out those which we've classified
		# (cron job will clear these out after a month, so that data doesn't go stale)
		Models.Classify.find(user:u, saved:{$exists:true}, contact:{$in:contactsList}).select('contact').exec (err, saves) ->
			throw err if err
			if saves?.length
				saves = _.map saves, (s)->s.contact.toString()
				contactsList = _.difference contactsList, saves
				unless contactsList.length then return cb contactsList

			# finally, most difficult filter: the (temporary) skips.
			# skips are classified records that dont have the 'saved' flag set.
			Models.Classify.find(user:u, saved:{$exists:false}, contact:$in:contactsList).select('contact').exec (err, skips) ->
				throw err if err
				if skips?.length
					skips = _.filter skips, (skip)->	# skips only count for messages prior to the skip
						not _.some msgs, (msg)->
							msg.recipient.toString() is skip.contact.toString() and Models.tmStmp(msg._id) > Models.tmStmp(skip._id)
					if skips.length
						skips = _.map skips, (s)->s.contact.toString()
						contactsList = _.difference contactsList, skips
				cb contactsList


#
# generate the list of contacts to classify.
#
# the lazy flag is for when we're trying not to be TOO enthusiastic about finding contacts to classify.
# If we're hitting the classify page, lazy is false, and we look back in time to classify old contacts
# that were added before this month, but never classified.
# If we're showing a count, or listing them in an email, we don't bother being so keen.
#
classifyList = (u, cb, lazy=false)->
	if _.isString(u) then u = Models.ObjectId(u)
	# for power users, there'll eventually be a large number of excludes
	# whereas with an aggressive classification policy there'll never be too many unclassified contacts/user
	# so first get the list of new contacts, then the subset of those who are not excluded
	Models.Mail.find({sender:u, sent: $gt: lastMonth}).select('recipient').exec (err, msgs) ->
		throw err if err
		# every recent recipient is a candidate for the queue
		neocons = _.uniq _.map msgs, (m)->m.recipient.toString()
		msgs=null

		stripSome u, msgs, neocons, (neocons)->
			if neocons.length is 20 then return cb neocons
			if neocons.length < 20	# less than 20? look for added but not classified
				if lazy then return cb neocons	# unless this is a lazy (count, classifySome) search
				return Models.Contact.find(added:{$exists:true}, addedBy:u, classified:{$exists:false}).select('_id').exec (err, unclassified) ->
					if err or not unclassified?.length then return cb neocons
					unclassified = _.uniq _.map unclassified, (m)->m._id.toString()
					stripSome u, msgs, unclassified, (unclassified)->
						if not unclassified.length then return cb neocons
						neocons = _.union neocons, unclassified
						return cb neocons[0..20]
			# but if there's more than 20, let's prioritise those that are brand new
			Models.Contact.find(added:{$exists:false}, _id:$in:neocons).select('_id').exec (err, unadded) ->
				if not err and unadded.length
					unadded = _.map unadded, (c)->c._id.toString()
					if unadded.length < 20
						neocons = _.union unadded, neocons
					else neocons = unadded
				return cb neocons[0...20]


classifySome = (u, cb)->
	classifyList u, (neocons)->
		if not neocons?.length then return cb null, null
		Models.Contact.find {_id:$in:neocons}, (err, unadded)->
			if err or not unadded?.length then return cb err, null
			names = []
			for contact in unadded
				if name = _.first(contact.names) then names.push name
				else
					if (email = _.first(contact.emails))
						splitted = email.split '@'
						domain = _.first _.last(splitted).split('.')
						names.push "#{_.first(splitted)} [#{domain}]"
					else
						console.log "error getting name for:"
						console.dir contact
			return cb null, names
	, true	# set the lazy flag


summaryUnclassified = (cb) ->
	Models.Contact.where('added').gt(lastWeek).where('classified').exists(false).count cb

summaryQuery = (model, field, cb) ->
	Models[model].where(field).gt(lastWeek).count cb

summaryTags = (cb) ->
	Models.Tag.where('date').gt(lastWeek).where('deleted').exists(false).count cb

searchCount = (cb)->
	Models.Admin.findOne {_id:1}, (err, adm)->
		if err then return cb err, null
		count = adm.searchCnt
		for c in adm.searchCounts
			count += c
		cb null, count

module.exports =
	recentConts:recentConts
	recentOrgs:recentOrgs
	classifySome:classifySome
	classifyList:classifyList
	searchCount: searchCount
	summaryUnclassified: summaryUnclassified
	summaryContacts: (cb)-> summaryQuery 'Contact', 'added', cb
	summaryActive: (cb)-> summaryQuery 'User', 'lastLogin', cb
	summaryIntros: (cb)-> summaryQuery 'IntroMail', 'date', cb
	summaryNotes: (cb)-> summaryQuery 'Note', 'date', cb
	summaryReqs: (cb)-> summaryQuery 'Request', 'date', cb
	summaryResps: (cb)-> summaryQuery 'Response', 'date', cb
	summaryTags: (cb)-> summaryTags cb
	countConts: (cb)-> Models.Contact.find(added:{$exists:true}).count cb
	myConts: (u, cb)-> Models.Contact.find(addedBy:u).where('added').gt(lastWeek).count cb
	classifyCount: (u, cb)->
		classifyList u, (neocons)->
			cb neocons?.length
		, true	# set the lazy flag ...
	requestCount: (u, cb)->
		Models.Request.find(
			expiry:{$gte:moment().toDate()}
			user:{$ne:u}
		).execFind (err, reqs)->
			filtaRex = (filtered_rex)->
				if not reqs?.length
					return cb filtered_rex.length
				req = reqs.pop()
				Models.Response.find({user:u, _id:{$in:req.response}}).count (err, count)->
					if not count then filtered_rex.push req._id
					filtaRex filtered_rex
			filtaRex []

