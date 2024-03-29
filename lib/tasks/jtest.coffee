
moment = require 'moment'
_ = require 'underscore'

services = require 'phrenetic/lib/server/services'

models = require '../server/models'
Elastic = require '../server/elastic'



# automagically save new contacts if they're not classified (or skipped) within 5 days.
eachSave = (user, done)->

	id = user._id
	fiveDays = moment().subtract('days', 5)
	models.Contact.find({
		knows: id
		added: $exists: false
		date: $lt: fiveDays
	}).select('_id').exec (err, unadded) ->
		throw err if err

		# get the list of likely queue entries
		neocons = _.uniq _.map unadded, (u)->u._id.toString()

		# first strip out those who are permanently excluded
		models.Exclude.find(user:id, contact:$in:neocons).select('contact').exec (err, ludes) ->
			throw err if err
			neocons =  _.difference neocons, _.map ludes, (l)->l.contact.toString()
			if not neocons.length then return done()

			# then strip out the temporary skips:
			# recent classify records that dont have the 'saved' flag set.
			class_match = { user:id, saved:{$exists:false}, contact:$in:neocons }
			models.Classify.find(class_match).select('contact').exec (err, skips) ->
				throw err if err
				skips = _.filter skips, (skip)->	# skips only count for messages prior to the skip
					not _.some unadded, (u)->
						u._id.toString() is skip.contact.toString() and models.tmStmp(u._id) > models.tmStmp(skip._id)
				neocons = _.difference neocons, _.map skips, (k)->k.contact.toString()
				if not neocons.length then return done()
				updates = { added: new Date(), addedBy: id }
				matches = _id: $in: neocons
				options = { safe:true, multi:true }
				models.Contact.update matches, updates, options, (err)->
					if err then return done()
					models.Contact.find matches, (err, contacts)->
						if not err then while contacts?.length
							Elastic.create contacts.pop()
						done()


# these are all the operations which are used with EachDoc

# set a contact record to added
eachUpAdd = (contact, cb)->
	contact.added = new Date()
	contact.addedBy = contact.knows[0]
	contact.save (err)->
		if err then console.log "Error force adding .. #{contact._id}"
		cb()

# trawl through a user's linkedin network
eachLink = (user, cb)->
	email = user?.email
	try require('../server/linker') user, null, (err, changes)->
		if err
			console.log "error in nudge link for #{email}"
			console.dir err
			cb()
		else
			user.lastLink.date = new Date()
			user.lastLink.count = changes?.length
			user.save (err)->
				if err then console.log "Error saving linkedin count in nudge for #{email}"
				cb()
	catch err
		console.log "error in nudge link for #{email}"
		console.dir err
		cb()

# parse a user's emails
eachParse = (user, cb, succinct_manual)->
	console.log "parsing #{user.email}"
	try require('../server/parser') user, null, cb, succinct_manual
	catch err
		console.log "error in nudge parse for #{user.email}"
		console.dir err
		cb()

# recursively operate on a list of documents
eachDoc = (docs, operate, fcb, succinct_manual) ->
	if not docs.length then return fcb()
	doc = docs.pop()
	operate doc, ()->
		eachDoc docs, operate, fcb, succinct_manual
	, succinct_manual



# these operations are performed every time the cron job is called

dailyRoutines = (doneDailies)->
	return doneDailies()
	# tidy up the classify records each day, to expire skips and saves
	###
	# we used to do it on the ID,
	# but now the 'saved' field is a Date.
	suffix="0000000000000000"	# append this to time 16 char time in secs to get an ObjectId timestamp
	prefix = Math.floor(moment().subtract('months', 1).valueOf()/1000).toString(16)
	models.Classify.remove {_id : $lt : new models.ObjectId "#{prefix}#{suffix}"}, (err)->
	###
	models.Classify.remove {saved:{$exists:true}, saved:$lt:moment().subtract('months',1).toDate()}, (err)->
		if err
			console.log "Error removing old classifies (saves): IDs less than #{prefix}#{suffix}"
			console.dir err

		# skips (not saved) are removed after two weeks
		suffix = "0000000000000000"	# append this to time 16 char time in secs to get an ObjectId timestamp
		prefix = Math.floor(moment().subtract('days', 14).valueOf()/1000).toString(16)
		models.Classify.remove {saved: {$exists: false}, _id: {$lt: new models.ObjectId "#{prefix}#{suffix}"}}, (err)->
			if err
				console.log "Error removing old classifies (skips): IDs less than #{prefix}#{suffix}"
				console.dir err

			if _.contains process.env.NUDGE_DAYS.split(' '), moment().format('dddd')
				console.log "dailydone"
				return doneDailies()

			# if we're not nudging today, let's take the time to make sure every added contact is searchable
			models.Contact.find {added: $exists: true}, (err, contacts)->
				if not err and contacts?.length
					_.each contacts, (c)->
						Elastic.get c._id, (err, data)->
							if err or not data
								console.log "SANITY CHECK: creating ES index for missing contact #{c._id}"
								Elastic.create c
				Elastic.scan (err, id)->
					if err or not id
						console.log "SANITY CHECK: ES.scan err:"
						console.dir err
						console.dir id
						return doneDailies()
					hitAtATime = (hits)->
						if not hits?.length then return scrollAtATime()
						hit = hits.pop()
						models.Contact.findById hit._id, (err, c)->
							if err or not c then Elastic.delete hit._id
							hitAtATime hits
					scrollAtATime = ()->
						Elastic.scroll id, (err, data)->
							if err
								console.log "SANITY CHECK: ES.scroll err:"
								console.dir err
								return doneDailies()
							if not data?.hits?.hits?.length then return doneDailies()
							id = data._scroll_id
							hitAtATime data.hits?.hits
					scrollAtATime()


resetEachRank = (cb, users)->
	if not l = users?.length then return cb()
	user = users.shift()
	models.Contact.count {addedBy:user.id}, (err, fc)->
		if not err then user.fullCount = fc
		models.Contact.count {addedBy:user.id, classified:$exists:false}, (err, ucc)->
			if not err then user.unclassifiedCount = ucc

			DAYS_PER_MONTH = 30

			if not user.oldDcounts then user.oldDcounts = []
			user.oldDcounts.unshift() while user.oldDcounts?.length > DAYS_PER_MONTH
			if user.oldDcounts?.length is DAYS_PER_MONTH then user.dataCount -= user.oldDcounts.unshift()
			if not user.oldDcounts?.length then user.oldDcounts = [user.dataCount]
			else user.oldDcounts.push user.dataCount - _.reduce(user.oldDcounts, (t, s)-> t + s)

			if not user.oldCcounts then user.oldCcounts = []
			user.oldCcounts.unshift() while user.oldCcounts?.length > DAYS_PER_MONTH
			if user.oldCcounts?.length is DAYS_PER_MONTH then user.contactCount -= user.oldCcounts.unshift()
			if not user.oldCcounts?.length then user.oldCcounts = [user.contactCount]
			else user.oldCcounts.push user.contactCount - _.reduce(user.oldCcounts, (t, s)-> t + s)

			if not user.oldDcounts then user.oldDcounts = []
			user.oldRanks.push l
			user.oldRanks.unshift() until user.oldRanks?.length < DAYS_PER_MONTH
			user.lastRank = user.oldRanks[0]

			user.save (err)->
				if err then console.log "Error resetting rank .. #{user._id}"
				resetEachRank cb, users


maybeResetRank = (doit, users, cb)->
	if not doit then users = null
	if not l = users?.length then return cb()
	resetEachRank cb, _.sortBy users, (u)->
		((u.contactCount or 0) + (u.dataCount or 0))*l + l - (u.lastRank or 0)


# work begins here:
console.log "starting nudge with flag: #{process.argv[3]}"

# first, run the daily routines
dailyRoutines ->

	# then, the nudge and linkedin only happen on scheduled days,
	# (or if we force it with the manual flag from the command line)
	succinct_manual = (process.argv[3] is 'manual')
	only_daily = (process.argv[3] is 'daily')
	dont_do_parse = false


	return models.User.find {email: 'justin@redstar.com'}, (err, users) ->
		eachDoc users, eachSave, ()->
			console.log "nudge: DONE test"
			return services.close()


	models.User.find (err, users) ->
		throw err if err

		maybeResetRank not succinct_manual, users, ->

			models.User.find (err, users) ->
				throw err if err
				console.log "nudge: auto saving old queue items"
				eachDoc users, eachSave, ()->

					if only_daily
						console.log "nudge: just manually ran the daily routines."
						return services.close()
					if not succinct_manual
						console.log "not running manual nudge."
						if not _.contains process.env.NUDGE_DAYS.split(' '), moment().format('dddd')
							console.log "Today = #{moment().format('dddd')} isnt in the list :"
							console.dir process.env.NUDGE_DAYS.split(' ')
							# return services.close()
							dont_do_parse = true

					models.User.find (err, users)->
						throw err if err
						console.log "nudge: scanning linkedin"
						eachDoc users, eachLink, ()->
							if dont_do_parse then return services.close()
							models.User.find (err, users) ->
								throw err if err
								console.log "nudge: parsing emails"
								eachDoc users, eachParse, ()->
									console.log "nudge: DONE parsed emails"
									return services.close()
								, succinct_manual

