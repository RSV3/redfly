_ = require 'underscore'
request = require 'request'
models = require './models'

linkLater = require('./linklater')
addDeets2Contact = linkLater.addDeets2Contact
REImake = linkLater.REImake


# async (but serial, consecutive with callback) collection processing

syncForEach = (list, iterator, final_cb, count=0) ->
	if not list?.length then return final_cb()
	item = list.shift()
	iterator item, count++, () ->
		syncForEach list, iterator, final_cb, count


#
# partial: the main guts of the api call
# options: to be added on the end following the format specifier
# oa: oauth details
# cb: callback for response
#
getLinked = (partial, options, oa, cb) ->
	url = 'http://api.linkedin.com/v1/people' + partial + '?format=json'
	if options and options.length then url = "#{url}&#{options}"
	try
		request.get
			url: url
			oauth: oa
			json: true
		, (error, response, body) ->
			if not error and response.statusCode is 200
				cb null, body
			else
				error =
					message: response.body.message
					statusCode: response.statusCode
				console.log "LINKEDIN debug: #{url}"
				console.dir error
				cb error, null
	catch error
		console.log "ERROR getting LINKEDIN #{partial}"
		console.dir oa
		console.dir error
		cb error, null



#
# confirm is a callback that takes a boolean
# to indicate whether the linkedin id, or matched contact, have already been done this week
#
alreadyLinked = (profid, contact, confirm) ->
	lastWeek = new Date()
	lastWeek.setDate(lastWeek.getDate() - 7)
	if contact then query = {contact:contact}
	else query = {linkedinId: profid}
	models.LinkedIn.findOne query, {lastLink:true}, (err, linkedin) ->
		if err or not linkedin then return confirm false
		if not linkedin.lastLink or linkedin.lastLink < lastWeek then return confirm false
		confirm true


#
# confirm whether the linkedin id, or matched contact, have already been done today
#
getDeets = (id, profid, contact, oa, cb) ->
	alreadyLinked profid, contact, (test) ->
		if test then return cb null, null
		u = ('/id=' + id + ':(industry,specialties,positions,picture-urls::(original),headline,summary,public-profile-url)')
		getLinked u, null, oa, cb


#
# paginate the connections
#
getConnections = (parturl, oauth, cb, sofar=values:[]) ->
	count = 500		# maximum per page. lets use a variable in case the api changes, etc
	getLinked parturl, "start=#{sofar.values.length}&count=#{count}", oauth, (err, tranche) ->
		if not err and tranche
			if not sofar then sofar = tranche
			else sofar.values = sofar.values.concat tranche.values
			if tranche.values.length is count					# our work here is done
				return getConnections parturl, oauth, cb, sofar
		cb err, sofar
		
#
# Given two linkedin startDate/ endDate objects
# { month:month, year:year }
# return difference in months
#
liCountMonths = (d_from, d_to) ->
	if not d_to or not d_to.year or not d_from or not d_from.year
		return 0
	months = (d_to.year - d_from.year) * 12
	if d_to.month
		months += d_to.month
	if d_from.month
		months -= d_from.month
	months


#
# Given two linkedin start_date/ end-date objects
# { month:month, year:year }
# return:
# -1 if d1<d2
# +1 if d1>d2
# 0 if d1==d2
#
liDateCompare = (d1, d2) ->
	if not d1 or not d2
		return 0
	if d1.year < d2.year
		return -1
	if d1.year > d2.year
		return 1
	if d1.month < d2.month
		return -1
	if d1.month > d2.month
		return 1
	return 0


###
#
# calculate years of experience for this contact.
#
# get the industry tags of the contact's (primary) current position
# get the years in current position from the start date
# find all past and preset positions that share industry tags with the primary current position
# make a list of start end dates for those past positions
# flatten that list, mindful of overlaps to get total years experience
#
###
calculateExperience  = (contact, details) ->
	months = 0

	if contact and (contact.position or contact.company)
		current = {position: contact.position, company: contact.company}
	else if details.positions and details.positions.length
		current = {position: details.positions[0].title, company: details.positions[0].company.name}
	else return 0		# no position to have experience in...

	for position in details.positions
		if position.title is current.position and position.company.name is current.company
			whichpos = position
	if not whichpos					# maybe it was a promotion?
		for position in details.positions
			if position.company.name is current.company and (not position.endDate or not position.endDate.year)
				whichpos = position
	if not whichpos then return 0		# if we still can't match current position/company, return 0

	for position in details.positions
		if position isnt whichpos
			if position.company.industry == whichpos.company.industry
				if liDateCompare(position.startDate, whichpos.startDate) < 0	# older position/ same industry
					whichpos = position

	d = new Date()
	first_d =
		month: d.getMonth()
		year: d.getFullYear()
	latest_d = whichpos.startDate
	months += liCountMonths latest_d, first_d
	
	for position in details.pastpositions
		if position.company.industry is whichpos.company.industry
			if liDateCompare(position.startDate, latest_d) < 0
				if liDateCompare(position.endDate, latest_d) < 0
					latest_d = position.endDate
				months += liCountMonths position.startDate, latest_d
				latest_d = position.startDate

	Math.round(months/12)


#
# split a string by commas, dashes or bullets,
# whichever is dominant ...
#
splitSpecials = (specialties) ->
	if specialties
		splitchar = ','
		splitcount = specialties.match(/,/g)?.length
		othercount = specialties.match(/-/g)?.length
		if splitcount < othercount
			splitchar = '-'
			splitcount = othercount
		othercount = specialties.match(/\u2022/g)?.length
		if splitcount < othercount
			splitchar = '\u2022'
			splitcount = othercount
		specialties.split splitchar


###
add new contact details to the queue for this user
###
push2linkQ = (notifications, user, contact, details, cb) ->
	specialties = splitSpecials details.specialties

	positions = _.pluck details.positions, 'title'
	companies = _.pluck details.positions, 'company'
	industries = _.pluck companies, 'industry'
	industries.unshift details.industry
	companies = _.pluck companies, 'name'
	details.yearsExperience = calculateExperience contact, details

	addDeets2Linkedin user, contact, details,
		specialties:specialties
		industries:industries
		companies:companies
		positions:positions
	, (linkedin)->
		if linkedin and contact and not _.isArray(contact)	# only if we're certain which contact this matches,
			cb addDeets2Contact notifications, user, contact, linkedin
		else cb null


updateLIrec = (details, linkedin, field)->
	if details[field] then linkedin[field] = details[field]

saveLinkedin = (details, listedDetails, user, contact, linkedin, cb) ->
	if not linkedin
		linkedin = new models.LinkedIn
		linkedin.contact = contact
		linkedin.linkedinId = details.profileid
		linkedin.users = []
		linkedin.name =
			firstName: details.firstName
			lastName: details.lastName
			formattedName: details.formattedName
	linkedin.users.addToSet user
	updateLIrec details, linkedin, 'yearsExperience'
	updateLIrec details, linkedin, 'pictureUrl'
	updateLIrec details, linkedin, 'publicProfileUrl'
	updateLIrec details, linkedin, 'summary'
	updateLIrec details, linkedin, 'headline'
	for detail, list of listedDetails
		if list and list.length
			for item in list
				if item and item.length
					if not linkedin[detail]
						linkedin[detail] = [item]
					else if (_.indexOf linkedin[detail], item) < 0
						linkedin[detail].addToSet item
	linkedin.lastLink = new Date()
	linkedin.save (err) ->
		if err then console.dir err
		cb linkedin


addDeets2Linkedin = (user, contact, details, listedDetails, cb) ->
	if _.isArray(contact)	# if this linkedin connection matches multiple contacts,
		contact = null		# just store the deets, without trying to match
	if contact
		models.LinkedIn.findOne {contact: contact}, (err, linkedin) ->
			throw err if err
			if linkedin and not linkedin.linkedinId?.length 	# possible artifact of an old error
				console.log "warning: overwriting linkedin ID #{details.profileid} on #{linkedin._id}"
				linkedin.linkedinId = details.profileid
			saveLinkedin details, listedDetails, user, contact, linkedin, cb
	else
		models.LinkedIn.findOne {linkedinId: details.profileid}, (err, linkedin) ->
			throw err if err
			saveLinkedin details, listedDetails, user, contact, linkedin, cb


#
# after submitting a query on contact name, try to narrow down the results ...
#
_matchContact = (userId, contacts, cb) ->
	if not contacts.length then return cb null
	if (contacts.length > 1)
		nc = _.select contacts, (c) -> (_.indexOf c.knows, userId) >= 0
		if nc.length then contacts = nc
	if (contacts.length > 1)
		nc = _.select contacts, (i) -> i.addedBy is userId
		if nc.length then contacts = nc
	cb contacts[0]


###
# first tries to match contacts with name
# if that fails, tries again with case insensitive regexp (that we know fails on unicode)
###
matchInsensitiveContact = (name, cb) ->
	###
	models.Contact.find names: name, (err, contacts) ->
		throw err if err
		if not _.isEmpty contacts
			cb contacts
		else
	###
	if not rName = REImake(name) then return cb null
	models.Contact.find names: rName, (err, contacts) ->
		throw err if err
		cb contacts

###
find a contact for this user that matches "first last" or "formatted"
and send best match to the callback.

first see if there's only one contact in the system with that name
failing that, try to pin it down to one contact already known to this user
still too many? maybe try to narrow in to the ones this user added :
 - in this manner, we try to return a single contact

but if this won't work, return an array of possible matches, and let spongebob sort them out
TODO: one option might be to make a (n+1)-th contact, and let the user merge (if they can ...)
###
matchContact = (userId, first, last, formatted, cb) ->
	name = "#{first} #{last}"
	matchInsensitiveContact name, (contacts) ->
		if contacts or name is formatted then _matchContact userId, contacts, cb
		else matchInsensitiveContact formatted, (contacts) ->
			_matchContact userId, contacts, cb


#
# gets the profile ID from an item returned from a linkedin profile query
# as used in various site URLs
#
profileIdFrom = (item) ->
	id = item.siteStandardProfileRequest?.url
	if id
		i = id.indexOf('key=')
		if i < 0
			i = id.indexOf('id=')+3
		else i+=4
		id = id.substr i
	id?.substr 0, id.indexOf('&')


linker = (user, notifications, finalCB) ->
	auth = user.linkedInAuth
	if not auth or not auth.token then return finalCB null, null

	fn = (err, changed, count=0) ->
		if not count and not user.linkedInThrottle or count is user.linkedInThrottle
			return finalCB err, changed
		user.linkedInThrottle = count		# keep track of where we were up to when we got throttled
		user.save (othererror) ->
			finalCB err, changed			# then exit (final callback) with list of changed contacts

	oauth =
		consumer_key: process.env.LINKEDIN_API_KEY
		consumer_secret: process.env.LINKEDIN_API_SECRET
		token: auth.token
		token_secret: auth.secret

	parturl = '/~/connections:(id,first-name,last-name,formatted-name,site-standard-profile-request)'
	getConnections parturl, oauth, (err, network) ->
		if err or not network
			console.log parturl + ' failed.'
			return fn err, null

		changed = []		# build an array of changed contacts to broadcast
		notifications?.foundTotal? network.values.length
		countSomeFeed = 9		# only add the first few new items to the feed

		liProcess = (item, contact, cb, counter=-1) ->
			if item.id is 'private' then return cb()	# don't even bother trying for contacts who block API access
			getDeets item.id, profileIdFrom(item), contact, oauth, (err, deets) ->
				notifications?.completedContact?()
				if err
					if err.statusCode is 403
						if counter < 0 then return fn null, changed	# don't report throttle if counter not passed
						console.log "linkedin process throttled"
						console.dir err
						return fn err, changed, counter
					console.log "error in linkedin process"
					console.dir err
					return cb()
				unless deets then return cb()
				for key, val of deets		# copy profile, splitting past and present positions
					if key is 'positions'
						item[key] = _.select val.values, (p) -> p.isCurrent
						item.pastpositions = _.select val.values, (p) -> not p.isCurrent
					else if key is 'pictureUrls'
						if val._total then item.pictureUrl = val.values[0]
					else item[key] = val
				if countSomeFeed then countSomeFeed--
				else notifications?.updateFeeds = null
				push2linkQ notifications, user, contact, item, (id)->
					if id then changed.push id
					cb()

		maybeMore = []
		if (user.linkedInThrottle < network.values.length)		# recall where we were up to when we got throttled
			network.values = network.values[user.linkedInThrottle..]
		syncForEach network.values, (item, counter, cb) ->
			item.profileid = profileIdFrom item
			matchContact user._id, item.firstName, item.lastName, item.formattedName, (contact) ->
				notifications?.completedLinkedin?()
				if not contact				# if this connection doesn't match a contact
					maybeMore.push item		# don't bother pulling down more linkedin data on them just yet
					cb()
				else
					liProcess item, contact, cb, counter		# matches contact, so get more data
		, ->
			if not maybeMore.length				# if there's no connections that didn't match a contact
				return fn null, changed			# then just exit with a list of changed contacts
			syncForEach maybeMore, (item, counter, cb) ->	# 2nd parse, through list of other connections
				liProcess item, null, cb, counter		# let's experiment with remembering the counter ...
			, ->
				return fn null, changed			# at the end of the 2nd parse, return list of changed contacts

#
# this module hooks up with linkedin using the supplied oauth2 credentials
# pulls down the user's linked in network
# and saves the data in a linkedin collection,
# optionally updating contacts that may match those record.
#
# If the notifications object has the right vectors they fire during the process
#
# module.exports = linker
module.exports =
	linker:linker
	addDeets:addDeets2Linkedin
	matchContact:matchContact
