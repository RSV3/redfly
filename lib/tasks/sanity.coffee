
moment = require 'moment'
_ = require 'underscore'

services = require '../../phrenetic/lib/server/services'

Models = require '../server/models'
Elastic = require '../server/elastic'

Goodbye = ->
	services.close()
	process.exit()


sanityRoutine = ()->
	Models.Contact.find {added: $exists: true}, (err, contacts)->
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
				return Goodbye()
			hitAtATime = (hits)->
				if not hits?.length then return scrollAtATime()
				hit = hits.pop()
				Models.Contact.findById hit._id, (err, c)->
					if err or not c then Elastic.delete hit._id
					hitAtATime hits
			scrollAtATime = ()->
				Elastic.scroll id, (err, data)->
					if err
						console.log "SANITY CHECK: ES.scroll err:"
						console.dir err
						return Goodbye()
					if not data?.hits?.hits?.length then return Goodbye()
					id = data._scroll_id
					hitAtATime data.hits?.hits
			scrollAtATime()


# work begins here:
if _.contains process.env.NUDGE_DAYS.split(' '), moment().format('dddd') then return Goodbye()
console.log "starting sanity check"
return sanityRoutine()

