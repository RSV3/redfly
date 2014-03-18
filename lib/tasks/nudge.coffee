
moment = require 'moment'
_ = require 'underscore'

services = require '../../phrenetic/lib/server/services'

Models = require '../server/models'
Elastic = require '../server/elastic'

Goodbye = ->
	services.close()
	process.exit()

# automagically save new contacts if they're not classified (or skipped) within 5 days.
eachSave = (user, done)->

	id = user._id
	fiveDays = moment().subtract('days', 5)
	Models.Contact.find({
		knows: id
		added: $exists: false
		date: $lt: fiveDays
	}).select('_id').exec (err, unadded) ->
		throw err if err

		# get the list of likely queue entries
		neocons = _.uniq _.map unadded, (u)->u._id.toString()
		if not neocons?.length then return done()

		# first strip out those who are permanently excluded
		Models.Exclude.find(user:id, contact:$in:neocons).select('contact').exec (err, ludes) ->
			throw err if err
			if ludes?.length
				neocons =  _.difference neocons, _.map ludes, (l)->l?.contact?.toString()
			if not neocons?.length then return done()

			# then strip out the temporary skips:
			# recent classify records that dont have the 'saved' flag set.
			class_match = { user:id, saved:{$exists:false}, contact:$in:neocons }
			Models.Classify.find(class_match).select('contact').exec (err, skips) ->
				throw err if err
				if skips?.length
					skips = _.filter skips, (skip)->	# skips only count for messages prior to the skip
						not _.some unadded, (u)->
							u._id.toString() is skip.contact.toString() and Models.tmStmp(u._id) > Models.tmStmp(skip._id)
				if skips?.length
					neocons = _.difference neocons, _.map skips, (k)->k.contact.toString()
				if not neocons?.length then return done()
				matches = _id: $in: neocons
				updates = { added: new Date(), addedBy: id }
				options = { safe:true, multi:true }
				Models.Contact.update matches, {$set:updates}, options, (err)->
					if err
						console.log "Error updating user #{id}'s contacts:"
						console.dir neocons
						console.dir err
						return done()
					else Models.Contact.find matches, (err, contacts)->
						if not err then while contacts?.length
							
							((c)->
								Elastic.create c, (err)->
									if err then return
									# industry tags may have been pre-populated, so:
									Models.Tag.find {contact:c._id, category:'industry'}, (err, tags)->
										if err then return
										while tags?.length
											t = tags.pop()
											Elastic.onCreate t, 'Tag', 'indtags'
							)(contacts.pop())
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
	console.log "link #{email}"
	try require('../server/linker').linker user, null, (err, changes)->
		if err
			console.log "received error in nudge link for #{email}"
			console.dir err
			cb()
		else
			user.lastLink.date = new Date()
			user.lastLink.count = changes?.length or 0
			user.save (err)->
				if err then console.log "Error saving linkedin count in nudge for #{email}"
				cb()
	catch err
		console.log "caught error in nudge link for #{email}"
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
		setImmediate ->										# stack defense
			eachDoc docs, operate, fcb, succinct_manual
	, succinct_manual


shiftSearchCount = ->
	DAYS_PER_WEEK = 7
	Models.Admin.findOne(_id:1).exec (err, admin)->
		if err then return console.dir err
		updates = { searchCounts: admin.searchCounts, searchCnt: admin.searchCnt }
		if not updates.searchCounts then updates.searchCounts = []
		if not updates.searchCnt then updates.searchCnt = 0
		updates.searchCounts.unshift updates.searchCnt
		if updates.searchCounts.length >= DAYS_PER_WEEK then updates.searchCounts.pop()
		updates.searchCnt = 0
		Models.Admin.update {_id:1}, {$set:updates}, {safe:true}, (err)->
			if err then console.dir err

# these operations are performed every time the cron job is called

dailyRoutines = (doneDailies)->
	shiftSearchCount()	# now we're counting searches, need to shift the array each week

	# tidy up the classify records each day, to expire skips and saves
	###
	# we used to do it on the ID,
	# but now the 'saved' field is a Date.
	suffix="0000000000000000"	# append this to time 16 char time in secs to get an ObjectId timestamp
	prefix = Math.floor(moment().subtract('months', 1).valueOf()/1000).toString(16)
	Models.Classify.remove {_id : $lt : new Models.ObjectId "#{prefix}#{suffix}"}, (err)->
	###
	Models.Classify.remove {saved:{$exists:true}, saved:$lt:moment().subtract('months',1).toDate()}, (err)->
		if err
			console.log "Error removing old classifies (saves): IDs less than #{prefix}#{suffix}"
			console.dir err

		# skips (not saved) are removed after two weeks
		suffix = "0000000000000000"	# append this to time 16 char time in secs to get an ObjectId timestamp
		prefix = Math.floor(moment().subtract('days', 14).valueOf()/1000).toString(16)
		Models.Classify.remove {saved: {$exists: false}, _id: {$lt: new Models.ObjectId "#{prefix}#{suffix}"}}, (err)->
			if err
				console.log "Error removing old classifies (skips): IDs less than #{prefix}#{suffix}"
				console.dir err

			console.log "dailydone"
			return doneDailies()


resetEachRank = (cb, users)->
	if not l = users?.length then return cb()
	if not user = users.shift() then return resetEachRank cb, users
	Models.Contact.count {addedBy:user.id}, (err, fc)->
		if not err then user.fullCount = fc
		Models.Contact.count {addedBy:user.id, classified:$exists:false}, (err, ucc)->
			if not err then user.unclassifiedCount = ucc

			DAYS_PER_MONTH = 30

			if not user.oldDcounts then user.oldDcounts = []
			while user.oldDcounts?.length > DAYS_PER_MONTH then user.oldDcounts.shift()
			if not user.dataCount then user.dataCount = 0
			if user.oldDcounts?.length is DAYS_PER_MONTH then user.dataCount -= user.oldDcounts.shift()
			if not user.oldDcounts?.length then user.oldDcounts = [user.dataCount]
			else user.oldDcounts.push user.dataCount - _.reduce(user.oldDcounts, (t, s)-> t + s)

			if not user.oldCcounts then user.oldCcounts = []
			while user.oldCcounts?.length > DAYS_PER_MONTH then user.oldCcounts.shift()
			if not user.contactCount then user.contactCount = 0
			if user.oldCcounts?.length is DAYS_PER_MONTH then user.contactCount -= user.oldCcounts.shift()
			if not user.oldCcounts?.length then user.oldCcounts = [user.contactCount]
			else user.oldCcounts.push user.contactCount - _.reduce(user.oldCcounts, (t, s)-> t + s)

			if not user.oldRanks then user.oldRanks = []
			while user.oldRanks?.length > DAYS_PER_MONTH then user.oldRanks.shift() 
			user.oldRanks.push l
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

	query = {}
	if process.argv.length is 5 then query.email = process.argv[4]

	Models.User.find query, (err, users) ->
		throw err if err

		maybeResetRank not succinct_manual, users, ->

			Models.User.find query, (err, users) ->
				throw err if err
				console.log "nudge: auto saving old queue items"
				eachDoc users, eachSave, ()->

					if only_daily
						console.log "nudge: just manually ran the daily routines."
						return Goodbye()
					if not succinct_manual
						console.log "not running manual nudge."
						if not _.contains process.env.NUDGE_DAYS.split(' '), moment().format('dddd')
							console.log "Today = #{moment().format('dddd')} isnt in the list :"
							console.dir process.env.NUDGE_DAYS.split(' ')
							# return Goodbye()
							dont_do_parse = true

					Models.User.find query, (err, users)->
						throw err if err
						console.log "nudge: scanning linkedin"
						eachDoc users, eachLink, ()->
							if dont_do_parse then return Goodbye()
							Models.User.find query, (err, users) ->
								throw err if err
								console.log "nudge: parsing emails"
								if query.email then succinct_manual = false		# always send newsletter if just one user
								eachDoc users, eachParse, ()->
									console.log "nudge: DONE parsed emails"
									return Goodbye()
								, succinct_manual

