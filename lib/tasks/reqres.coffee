
moment = require 'moment'
_ = require 'underscore'

services = require 'phrenetic/lib/server/services'

models = require '../server/models'
Mail = require '../server/mail'


today = moment().toDate()		# get the stamp immediately. all data after this date will be picked up next time.
console.dir today

# replace the resp ID with a response object
updateReqResps = (resps, cb, newresps=[])->
	if not resps.length then return cb newresps
	resp = resps.pop()
	models.Response.findOne {_id:resp}, (err, response)->
		if not err then newresps.push response
		updateReqResps resps, cb, newresps

# replace the user ID with a user object, so too the response array
updateReqs = (reqs, cb, newrex=[])->				# convert user, response ids to objects
	if not reqs.length then return cb newrex
	rec = reqs.pop()
	models.User.findOne {_id:rec.user.toString()}, (err, user)->	# send the list of new requests to ever user
		if not err then rec._doc.user = user
		updateReqResps rec.response, (responses)->
			rec._doc.response = responses
			newrex.push rec
			updateReqs reqs, cb, newrex

updateRespContacts = (contacts, cb, newcs=[])->
	if not contacts.length then return cb newcs
	c = contacts.pop()
	models.Contact.findOne {_id:c}, (err, contact)->
		if not err then newcs.push contact
		updateRespContacts contacts, cb, newcs

# given a list of response objects, replace the contact and user fields with the corresponding object
updateRespItems = (resps, cb, newresps=[])->
	if not resps.length then return cb newresps
	resp = resps.pop()
	models.User.findOne {_id:resp.user}, (err, user)->
		if not err then resp._doc.user = user
		updateRespContacts resp.contact, (contacts)->
			if resp.body?.length or contacts?.length
				resp._doc.contact = contacts
				newresps.push resp
			updateRespItems resps, cb, newresps

# for each request, update the user, contact items on each response
updateResps = (reqs, cb, newrex=[])->
	if not reqs.length then return cb newrex
	rec = reqs.pop()
	updateRespItems rec.response, (responses)->
		if responses?.length
			rec._doc.response = responses
			newrex.push rec
		updateResps reqs, cb, newrex

# recursively operate on a list of documents
# ignoring those that match the current user
# Note: this is called after response objects are loaded, so user id is response[n].user
eachUserRequest = (users, reqs, operate, fcb) ->
	if not users.length then return fcb()
	u = users.pop()
	operate u, _.filter(reqs, (r)->
		r.user._id isnt u._id and not _.some r.response, (r)-> r.user is u._id
	), ()->
		eachUserRequest users, reqs, operate, fcb


# recursively operate on a list of documents
# ignoring those that don't match the current user
# Note: this is called after response objects are loaded, so user id is response[n].user._id
eachUserResponse = (users, reqs, operate, fcb) ->
	if not users.length then return fcb()
	u = users.pop()
	userex = _.filter reqs, (request)->
		request.user._id.toString() is u._id.toString() and _.some(request.response, (response)->
			response.user._id.toString() isnt u._id.toString() and (not request.updatesent or response.date > request.updatesent))
	operate u, userex, ()->
		eachUserResponse users, reqs, operate, fcb


batchNewReqs = (cb)->
	console.log "broadcasting requests..."
	# grab the most recent request to be sent out by this routine,
	# to make sure we don't bombard users with new requests every 5 mins
	models.Request.find(expiry:{$gt:today}, sent:{$exists: true}).sort({sent:-1}).limit(1).execFind (err, reqs)->
		if not err and reqs?.length
			if reqs[0].sent > moment().subtract('hours', 1).toDate()		# already sent requests within the last hour?
				return cb()										# don't send requests too often
		models.Request.find(expiry:{$gt:today}, $or:[{urgent:true}, {sent: $exists: false}]).sort({urgent:1, date:1}).execFind (err, reqs)->
			if err
				console.log "ERROR: finding unsent requests"
				console.dir err
				return services.close()
			if not reqs?.length then return cb()		# no new requests
			updateReqs reqs, (reqs)->				# convert user, response ids to objects
				models.User.find (err, users) ->	# send the list of new requests to ever user
					throw err if err
					eachUserRequest users, reqs, Mail.sendRequests, ()->
						models.Request.update {sent: $exists: false}, {sent:today}, {multi:true}, (err) ->
							if err
								console.log "ERROR: updating requests as sent"
								console.dir err
							return cb()


sendNewResps = (cb)->
	console.log "sending responses..."
	models.Request.find {expiry:{$gt:today}, updated:{$exists:true, $ne:null}}, (err, reqs)->
		if err
			console.log "ERROR: finding last sent request"
			console.dir err
			return services.close()
		if not reqs?.length then return cb()
		users = _.uniq _.map reqs, (r)-> r.user.toString()
		models.User.find {_id:$in:users}, (err, users) ->	# send lists of new responses to the user
			updateReqs reqs, (reqs)->						# convert user, response ids to objects
				updateResps reqs, (reqs)->					# and similarly populate contact, user on each resp.
					eachUserResponse users, reqs, Mail.sendResponses, ()->
						models.Request.update {expiry:{$gt:today}, updated:{$exists:true, $ne:null}}, {updated:null, updatesent:today}, {multi:true}, (err)->
							if err
								console.log "ERROR: updating requests as sent"
								console.dir err
							return cb()


batchNewReqs ->			# first send new requests to everyone, 
	sendNewResps ->		# then send new responses to those who need them
		services.close()
		process.exit()

