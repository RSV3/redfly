_ = require 'underscore'

models = require '../server/models'
linkLater = require('./linklater').linkLater;
addTags = require './addtags'

fcupd = (c, cb)->
	try
		require('./fullcontact') contact, (fullDeets) ->
			if fullDeets
				linkLater user, contact, ()->
					contact.save (err) ->		# new contact has been populated with data from the service
						if err
							console.log "Error saving Contact with FullContact data"
							console.dir err
							console.dir contact
						# now save the other records that need the contact reference: mail, fullcontact, tags
						_saveFullContact user, contact, fullDeets
						if fullDeets.digitalFootprint
							tags = _.pluck fullDeets.digitalFootprint.topics, 'value'
							addTags user, contact, 'industry', tags
						cb()
	catch err
		console.log "error in nudge parse"
		console.dir user
		console.dir err
		cb()

eachDoc = (docs, operate, fcb) ->
	if not docs.length then return fcb()
	doc = docs.pop()
	operate doc, ()-> eachDoc docs

models.Contacts.find (err, contacts) ->
	throw err if err
	eachDoc contacts, fcupd, ()->
		require('phrenetic/lib/server/services').close()
