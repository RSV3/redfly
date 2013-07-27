
moment = require 'moment'
_ = require 'underscore'

services = require 'phrenetic/lib/server/services'

models = require '../server/models'



# automagically save new contacts if they're not classified (or skipped) within 5 days.
eachSave = (user, done)->

	id = user._id
	fiveDays = moment().subtract('days', 5)
	models.Mail.find({
		sender: id
		added: $exists: false
		sent: $lt: fiveDays
	}).select('recipient added sent').exec (err, msgs) ->
		throw err if err

		# get the list of likely queue entries
		neocons = _.uniq _.map msgs, (m)->m.recipient.toString()

		# first strip out those who are permanently excluded
		models.Exclude.find(user:id, contact:$in:neocons).select('contact').exec (err, ludes) ->
			throw err if err
			neocons =  _.difference neocons, _.map ludes, (l)->l.contact.toString()

			# then strip out the temporary skips:
			# recent classify records that dont have the 'saved' flag set.
			class_match = { user:id, saved:{$exists:false}, contact:$in:neocons }
			models.Classify.find(class_match).select('contact').exec (err, skips) ->
				throw err if err
				skips = _.filter skips, (skip)->	# skips only count for messages prior to the skip
					not _.some msgs, (msg)->
						msg.recipient.toString() is skip.contact.toString() and models.tmStmp(msg._id) > models.tmStmp(skip._id)
				neocons = _.difference neocons, _.map skips, (k)->k.contact.toString()
				if neocons.length
					updates = { added: new Date(), addedBy: id }
					matches = id: $in: neocons
					models.Contact.update matches, updates, (err)->
						if err
							console.log "Error updating contacts:"
							console.dir neocons
							console.log "for user #{id}"
							console.dir err
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
	try require('../server/linker') user, null, cb
	catch err
		console.log "error in nudge link for #{user.email}"
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
		eachDoc docs, operate, fcb
	, succinct_manual



# these operations are performed every time the cron job is called

dailyRoutines = (doneDailies)->

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
		suffix="0000000000000000"	# append this to time 16 char time in secs to get an ObjectId timestamp
		prefix = Math.floor(moment().subtract('days', 14).valueOf()/1000).toString(16)
		models.Classify.remove {saved: {$exists: false}, _id: {$lt: new models.ObjectId "#{prefix}#{suffix}"}}, (err)->
			if err
				console.log "Error removing old classifies (skips): IDs less than #{prefix}#{suffix}"
				console.dir err
			doneDailies();


resetEachRank = (cb, users)->
	if not l = users.length then return cb()
	user = users.shift()
	models.Contact.count {addedBy:user.id}, (err, f)->
		if not err then user.fullCount=f
		user.dataCount=0
		user.contactCount=0
		user.lastRank=l
		user.save (err)->
			if err then console.log "Error resetting rank .. #{user._id}"
			resetEachRank cb, users


maybeResetRank = (doit, userlistcopy, cb)->
	if not doit then return cb()
	if process.env.RANK_DAY isnt moment().format('dddd') then return cb()
	if not l = userlistcopy.length then return cb()
	resetEachRank cb, _.sortBy userlistcopy, (u)->
		((u.contactCount or 0) + (u.dataCount or 0))*l + l - (u.lastRank or 0)


# work begins here:
console.log "starting nudge with flag: #{process.argv[3]}"

# first, run the daily routines
dailyRoutines ()->

	# then, the nudge and linkedin only happen on scheduled days,
	# (or if we force it with the manual flag from the command line)
	succinct_manual = (process.argv[3] is 'manual')
	only_daily = (process.argv[3] is 'daily')

	models.User.find (err, users) ->
		throw err if err

		maybeResetRank not succinct_manual, users.slice(), ->

			console.log "nudge: auto saving old queue items"
			eachDoc users.slice(), eachSave, ()->

				if only_daily
					console.log "nudge: just manually ran the daily routines."
					return services.close()
				if not succinct_manual 
					console.log "not running manual nudge."
					if not _.contains process.env.NUDGE_DAYS.split(' '), moment().format('dddd')
						console.log "Today = #{moment().format('dddd')} isnt in the list :"
						console.dir process.env.NUDGE_DAYS.split(' ')
						return services.close()

				console.log "nudge: scanning linkedin"
				eachDoc users.slice(), eachLink, ()->
					console.log "nudge: parsing emails"
					eachDoc users, eachParse, ()->
						return services.close()
					, succinct_manual

