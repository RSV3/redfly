
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
	console.log "parsing #{user.email} #{succinct_manual}"
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


# work begins here:
console.log "starting test"

query = {email: process.argv[3]}

models.User.find query, (err, users)->
	throw err if err
	console.log "test: parsing emails"
	eachDoc users, eachParse, ()->
		return services.close()
	, true

