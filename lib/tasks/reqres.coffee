
moment = require 'moment'
_ = require 'underscore'

services = require '../../phrenetic/lib/server/services'

models = require '../server/models'
Mail = require '../server/mail'
Logic = require '../server/logic'


Goodbye = ->
	services.close()
	process.exit()

today = moment().toDate()		# get the stamp immediately. all data after this date will be picked up next time.
console.dir today

# replace the resp ID with a response object
updateReqResps = (resps, cb, newresps=[])->
	if not resps?.length then return cb newresps
	resp = resps.pop()
	models.Response.findOne {_id:resp}, (err, response)->
		if not err then newresps.push response
		updateReqResps resps, cb, newresps

# replace the user ID with a user object, so too the response array
updateReqs = (reqs, cb, newrex=[])->				# convert user, response ids to objects
	if not reqs?.length then return cb newrex
	rec = reqs.pop()
	models.User.findOne {_id:rec.user.toString()}, (err, user)->	# send the list of new requests to ever user
		if not err then rec._doc.user = user
		updateReqResps rec.response, (responses)->
			rec._doc.response = responses
			newrex.push rec
			updateReqs reqs, cb, newrex

updateRespContacts = (contacts, cb, newcs=[])->
	if not contacts?.length then return cb newcs
	c = contacts.pop()
	models.Contact.findOne {_id:c}, (err, contact)->
		if not err then newcs.push contact
		updateRespContacts contacts, cb, newcs

# given a list of response objects, replace the contact and user fields with the corresponding object
updateRespItems = (resps, cb, newresps=[])->
	if not resps?.length then return cb newresps
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
	if not reqs?.length then return cb newrex
	rec = reqs.pop()
	updateRespItems rec.response, (responses)->
		if responses?.length
			rec._doc.response = responses
			newrex.push rec
		updateResps reqs, cb, newrex

# recursively operate on a list of documents
# ignoring those that match the current user
# Note: this is called after response objects are loaded, so user id is response[n].user
eachUserRequest = (users, uReqs, oReqs, operate, fcb) ->
	if not users?.length then return fcb()
	u = users.pop()
	filterRequests = (reqs)->
		_.filter(reqs, (req)->
			String(req.user._id) isnt String(u._id) and not _.some req.response, (resp)-> String(resp.user) is String(u._id)
		)
	operate u, filterRequests(uReqs), filterRequests(oReqs), ()->
		eachUserRequest users, uReqs, oReqs, operate, fcb


# recursively operate on a list of documents
# ignoring those that don't match the current user
# Note: this is called after response objects are loaded, so user id is response[n].user._id
eachUserResponse = (users, reqs, operate, fcb) ->
	if not users?.length then return fcb()
	u = users.pop()
	userex = _.filter reqs, (request)->
		request.user._id.toString() is u._id.toString() and _.some(request.response, (response)->
			response.user._id.toString() isnt u._id.toString() and (not request.updatesent or response.date > request.updatesent))
	operate u, userex, ()->
		eachUserResponse users, reqs, operate, fcb

# returns a curried function that injects the count in front of the args list any time operate is called
Inject = (contactCnt, operate)->
	->
		args = [contactCnt]
		for arg in arguments
			args.push arg
		operate.apply this, args


operateBatch = (uReqs, oReqs, operation, cb, urgentQuery, otherQuery)->
	if not uReqs?.length and not oReqs?.length then return cb()		# no new requests
	updateReqs uReqs, (uReqs)->				# convert user, response ids to objects
		updateReqs oReqs, (oReqs)->				# convert user, response ids to objects
			models.User.find query, (err, users) ->	# send the list of new requests to ever user
				throw err if err
				eachUserRequest users, uReqs, oReqs, operation, ()->
					models.Request.update urgentQuery, {$set:sent:today}, {multi:true}, (err) ->
						if err
							console.log "ERROR: updating urgent requests as sent"
							console.dir err
						if not otherQuery then return cb()
						models.Request.update otherQuery, {$set:sent:today}, {multi:true}, (err) ->
							if err
								console.log "ERROR: updating non-urgent requests as sent"
								console.dir err
							return cb()

batchUrgentReqs = (contCnt, cb)->
	console.log "broadcasting urgent requests..."
	urgentQ = {urgent:true, expiry:{$gt:today}, response:{$size:0}}
	models.Request.find(urgentQ).sort(date:-1).execFind (err, uReqs)->
		if err
			console.log "ERROR: finding unsent urgent requests"
			console.dir err
			return Goodbye()
		operateBatch uReqs, null, Inject(contCnt, Mail.resendRequests), cb, urgentQ

batchEmptyReqs = (contCnt, cb)->
	console.log "broadcasting empty requests..."
	otherQ = {urgent:{$ne:true}, expiry:{$gt:today}, response:{$size:0}}
	urgentQ = {urgent:true, expiry:{$gt:today}, response:{$size:0}}
	models.Request.find(urgentQ).sort(date:-1).execFind (err, uReqs)->
		if err
			console.log "ERROR: finding urgent unsent requests"
			console.dir err
			return Goodbye()
		models.Request.find(otherQ).sort(date:-1).execFind (err, oReqs)->
			if err
				console.log "ERROR: finding other unsent requests"
				console.dir err
				return Goodbye()
			operateBatch uReqs, oReqs, Inject(contCnt, Mail.resendRequests), cb, urgentQ, otherQ

batchNewReqs = (type, contCnt, cb)->
	if type is 'urgent' then return batchUrgentReqs contCnt, cb
	if type is 'empty' then return batchEmptyReqs contCnt, cb
	console.log "broadcasting requests..."
	otherQ = {urgent:{$ne:true}, expiry:{$gt:today}, sent:{$exists: false}}		# only care about new non-urgent requests
	urgentQ = {urgent:true, expiry:{$gt:today}}									# interested in any current urgent requests
	urgentQunsent  = _.extend {sent: $exists: false}, urgentQ					# but only iff there are some unsent requests
	urgentQsent  = _.extend {sent: $exists: true}, urgentQ						# so we query these separately
	models.Request.find(urgentQunsent).sort(date:-1).execFind (err, uReqs)->
		if err
			console.log "ERROR: finding urgent unsent requests"
			console.dir err
			return Goodbye()
		models.Request.find(otherQ).sort(date:-1).execFind (err, oReqs)->
			if err
				console.log "ERROR: finding unsent requests"
				console.dir err
				return Goodbye()
			unless (uReqs?.length or oReqs?.length) then return cb()			# if there's no unsent requests, bail out
			models.Request.find(urgentQsent).sort(date:-1).execFind (err, sentUreqs)->		# otherwise, append sent urgents
				if err
					console.log "ERROR: finding urgent sent requests"
					console.dir err
					return Goodbye()
				uReqs = uReqs.concat sentUreqs
				operateBatch uReqs, oReqs, Inject(contCnt, Mail.sendRequests), cb, urgentQ, otherQ


sendNewResps = (contCnt, cb)->
	console.log "sending responses..."
	models.Request.find {expiry:{$gt:today}, updated:{$exists:true, $ne:null}}, (err, reqs)->
		if err
			console.log "ERROR: finding last sent request"
			console.dir err
			return Goodbye()
		if not reqs?.length then return cb()
		users = _.uniq _.map reqs, (r)-> r.user.toString()
		respQuery = _id:$in:users
		if query.email then respQuery.email = query.email
		models.User.find respQuery, (err, users) ->	# send lists of new responses to the user
			updateReqs reqs, (reqs)->						# convert user, response ids to objects
				updateResps reqs, (reqs)->					# and similarly populate contact, user on each resp.
					eachUserResponse users, reqs, (Inject contCnt, Mail.sendResponses), ()->
						models.Request.update {expiry:{$gt:today}, updated:{$exists:true, $ne:null}}, {$set:{updated:null, updatesent:today}}, {multi:true}, (err)->
							if err
								console.log "ERROR: updating requests as sent"
								console.dir err
							return cb()


query = {}
if process.argv.length > 3
	if not _.contains ["urgent", "empty", "regular"], process.argv[3]
		console.log "Usage: node main tasks/reqres <urgent | empty | regular>"
		return Goodbye()
	else whichBatch = process.argv[3]
else if process.argv.length is 3
	switch "#{moment().hour()}"
		when process.env.URGENT_HOUR
			whichBatch = 'urgent'
		when process.env.EMPTY_HOUR
			whichBatch = 'empty'
		else whichBatch = 'regular'
if process.argv.length is 5 then query.email = process.argv[4]

console.log "#{whichBatch} batch job for requests / responses"

# calculate contacts count once, because every email will need to display it
Logic.countConts (err, contCnt)->
	if err then contCnt=0
	batchNewReqs process.argv[3], contCnt, ->			# first send new requests to everyone, 
		sendNewResps contCnt, ->		# then send new responses to those who need them
			Goodbye()
