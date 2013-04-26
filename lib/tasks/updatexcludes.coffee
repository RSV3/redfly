#
# this utility script is to augment old exclude records with contact ids
# instead of the name/email pair which was inherited from the old excludes array
# this will only need to be run once, then it's done.
#
_ = require 'underscore'

models = require '../server/models'

fixCludes = (doc, cb)->
	x = doc._doc
	models.Contact.find {emails:x.email}, (err, c) ->		# new contact has been populated with data from the service
		if err
			console.log "ERROR finding Contact to match xclude"
			console.dir err
			console.dir x
		else
			if c.length isnt 1
				console.log "ERROR! expecting 1 got #{c.length} contacts matching xclude #{x.email}"
			if c.length
				doc.contact = c[0]._id
				doc.save (err)->
					if err
						console.log "ERROR saving contact ID #{c._id} on exclude for #{x.email}(#{x._id})"
					cb()
			else cb()

eachDoc = (docs, operate, fcb) ->
	if not docs.length then return fcb()
	doc = docs.pop()
	operate doc, ()-> eachDoc docs, operate, fcb

models.Exclude.find (err, ludes) ->
	throw err if err
	eachDoc ludes, fixCludes, ()->
		require('phrenetic/lib/server/services').close()
