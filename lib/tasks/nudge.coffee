
moment = require 'moment'
_ = require 'underscore'

services = require 'phrenetic/lib/server/services'

models = require '../server/models'


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
eachDoc = (docs, operate, fcb) ->
	if not docs.length then return fcb()
	doc = docs.pop()
	operate doc, ()-> eachDoc docs, operate, fcb


# these operations are performed every time the cron job is called

dailyRoutines = (doneDailies)->

	# first, tidy up the classify records each day, to expire skips and saves
	prefix = Math.floor(moment().subtract('months', 1).valueOf()/1000).toString(16)
	suffix="0000000000000000"	# append this to time 16 char time in secs to get an ObjectId timestamp
	models.Classify.remove {_id : $lt : new models.ObjectId "#{prefix}#{suffix}"}, (err)->
		if err
			console.log "Error removing old classifies: IDs less than #{prefix}#{suffix}"
			console.dir err

		# next, automatically add contacts that have been in the system for 5 days and still have users in knows
		# (the 'skip' and 'skip forever' actions both take a user out of the list)

		prefix = Math.floor(moment().subtract('days', 5).valueOf()/1000).toString(16)
		query =
			added: $exists : false
			_id: $lt: new models.ObjectId "#{prefix}#{suffix}"
			knows: $not: $size: 0
		models.Contact.find query, (err, savem)->
			if err
				console.log "Error finding contacts to force add"
				console.dir query
				console.dir err
				return doneDailies()
			eachDoc savem, eachUpAdd, doneDailies


# work begins here:
console.log "starting nudge with flag: #{process.argv[3]}"

# first, run the daily routines
dailyRoutines ()->

	# then, the nudge and linkedin only happen on scheduled days,
	# (or if we force it with the manual flag from the command line)
	succinct_manual = (process.argv[3] is 'manual')
	only_daily = (process.argv[3] is 'daily')

	if only_daily
		console.log "just manually ran the daily routines."
		return services.close()
	if not succinct_manual 
		console.log "not running manual nudge."
		if not _.contains process.env.NUDGE_DAYS.split(' '), moment().format('dddd')
			console.log "Today = #{moment().format('dddd')} isnt in the list :"
			console.dir process.env.NUDGE_DAYS.split(' ')
			return services.close()

	models.User.find (err, users) ->
		throw err if err
		eachDoc users.slice(), eachLink, ()->
			eachDoc users, eachParse, ()->
				return services.close()
			, succinct_manual

