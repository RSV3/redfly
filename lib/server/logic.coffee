moment = require 'moment'
_ = require 'underscore'

models = require './models'

lastWeek = moment().subtract('days', 7).toDate()
lastMonth = moment().subtract('months', 1)


recentConts = (cb)->
	models.Contact.find({added:{$exists:true}}).sort(added:-1).limit(12).execFind (err, contacts)->
		if err then return cb err, contacts
		rcs = []
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


recentOrgs = (cb)->
	models.Contact.where('added').gt(lastWeek).execFind (err, contacts)->
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


classifyList = (u, cb)->
	if _.isString(u) then u = models.ObjectId(u)
	# for power users, there'll eventually be a large number of excludes
	# whereas with an aggressive classification policy there'll never be too many unclassified contacts/user
	# so first get the list of new contacts, then the subset of those who are not excluded
	models.Mail.find({sender:u, sent: $gt: lastMonth}).select('recipient').exec (err, msgs) ->
		throw err if err
		# every recent recipient is a candidate for the queue
		neocons = _.uniq _.map msgs, (m)->m.recipient.toString()
		msgs=null

		# first strip out those who are permanently excluded
		models.Exclude.find(user:u, contact:$in:neocons).select('contact').exec (err, ludes) ->
			throw err if err
			neocons =  _.difference neocons, _.map ludes, (l)->l.contact.toString()
			ludes=null

			# then strip out those which we've classified
			# (cron job will clear these out after a month, so that data doesn't go stale)
			models.Classify.find(user:u, saved:{$exists:true}, contact:{$in:neocons}).select('contact').exec (err, saves) ->
				throw err if err
				neocons =  _.difference neocons, _.map saves, (s)->s.contact.toString()
				saves=null

				# finally, most difficult filter: the (temporary) skips.
				# skips are classified records that dont have the 'saved' flag set.
				models.Classify.find(user:u, saved:{$exists:false}, contact:$in:neocons).select('contact').exec (err, skips) ->
					throw err if err
					skips = _.filter skips, (skip)->	# skips only count for messages prior to the skip
						not _.some msgs, (msg)->
							msg.recipient.toString() is skip.contact.toString() and models.tmStmp(msg._id) > models.tmStmp(skip._id)
					neocons = _.difference neocons, _.map skips, (k)->k.contact.toString()
					skips=null

					if neocons.length is 20 then return cb neocons
					if neocons.length < 20	# less than 20? look for added but not classified
						return models.Contact.find(added:{$exists:true}, addedBy:u, classified:{$exists:false}).select('_id').limit(20-neocons.length).exec (err, unclassified) ->
							if not err and unclassified.length
								neocons = _.union neocons, _.map unclassified, (c)->c._id.toString()
							return cb neocons
					# but if there's more than 20, let's prioritise those that are brand new
					models.Contact.find(added:{$exists:false}, _id:$in:neocons).select('_id').exec (err, unadded) ->
						if not err and unadded.length
							unadded = _.map unadded, (c)->c._id.toString()
							if unadded.length < 20
								neocons = _.union unadded, neocons
							else neocons = unadded
						return cb neocons[0...20]


classifySome = (u, cb)->
	classifyList u, (neocons)->
		if not neocons?.length then return cb null, null
		models.Contact.find {_id:$in:neocons}, (err, unadded)->
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


summaryQuery = (model, field, cb) ->
	models[model].where(field).gt(lastWeek).count cb


module.exports =
	recentConts:recentConts
	recentOrgs:recentOrgs
	classifySome:classifySome
	classifyList:classifyList
	summaryContacts: (cb)-> summaryQuery 'Contact', 'added', cb
	summaryTags: (cb)-> summaryQuery 'Tag', 'date', cb
	summaryNotes: (cb)-> summaryQuery 'Note', 'date', cb
	countConts: (cb)-> models.Contact.find(added:{$exists:true}).count cb
	myConts: (u, cb)-> models.Contact.find(addedBy:u).where('added').gt(lastWeek).count cb
	classifyCount: (u, cb)-> classifyList u, (neocons)-> cb neocons?.length
	requestCount: (u, cb)-> models.Request.find(expiry:$gte:moment().toDate()).count cb

# jTNT : TODO requestCount should probably check for current requests where
# $not notes.user:u, $not suggestions.user:u
# ie. requests which are not mine which I have not made a response to
