_ = require 'underscore'
request = require 'request'
util = require './util'
models = require './models'
validators = require('validator').validators


_syncForEach = (list, iterator, final_cb) ->
	if not list.length
		return final_cb()
	item = list.shift()
	iterator item, () ->
		_syncForEach list, iterator, final_cb

syncForEach = (list, iterator, final_cb) ->
	if not list.length
		return final_cb()
	_syncForEach list.slice(0), iterator, final_cb


getLinked = (partial, oa, cb) ->
	url = 'http://api.linkedin.com/v1/people' + partial + '?format=json'
	request.get
		url: url
		oauth: oa
		json: true
	, (error, response, body) ->
		if not error and response.statusCode is 200
			cb null, body
		else
			if not error or _.isString(error)
				error = 
					message: error
			error.statusCode = response.statusCode
			cb error, null


#
# confirm whether the linkedin id, or matched contact, have already been done this week
#
alreadyLinked = (id, contact, confirm) ->
	lastWeek = new Date()
	lastWeek.setDate(lastWeek.getDate() - 7)
	if contact
		query = {contact:contact}
	else
		query = {linkedinId: id}
	models.LinkedIn.findOne query, {lastLink:true}, (err, linkedin) ->
		if err or not linkedin
			return confirm false
		if not linkedin.lastLink or linkedin.lastLink < lastWeek
			return confirm false
		confirm true


#
# confirm whether the linkedin id, or matched contact, have already been done today
#
getDeets = (id, contact, oa, cb) ->
	alreadyLinked id, contact, (test) ->
		if test
			return cb null, null
		u = ('/id=' + id + ':(industry,specialties,positions,picture-url,headline,summary)')
		getLinked u, oa, cb


_addTags = (user, contact, category, existing, alist) ->
	if not alist.length then return
	tag = util.trim alist.shift().toLowerCase()
	if not _.select(existing, (t) -> t is tag).length
		newt = new models.Tag
			creator: user
			contact: contact
			category: category
			body: tag
		newt.save (err) ->
			_addTags user, contact, category, existing, alist
	else
		_addTags user, contact, category, existing, alist

addTags = (user, contact, category, alist) ->
	if not alist.length then return
	models.Tag.find {category: category, creator: user._id, contact: contact._id}, (err, existing) ->
		_addTags user, contact, category, _.pluck(existing, 'body'), alist


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

	for position in details.positions
		if position.title is contact.position and position.company.name is contact.company
			whichpos = position
	if not whichpos
		return months

	for position in details.positions
		if position isnt whichpos
			if position.company.industry == whichpos.company.industry
				if liDateCompare(position.startDate, whichpos.startDate) < 0
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
push2linkQ = (notifications, user, contact, details) ->
	specialties = splitSpecials details.specialties

	positions = _.pluck details.positions, 'title'
	companies = _.pluck details.positions, 'company'
	industries = _.pluck companies, 'industry'
	industries.unshift details.industry
	companies = _.pluck companies, 'name'

	addDeets2Linkedin user, contact, details, 
		specialties:specialties
		industries:industries
		companies:companies
		positions:positions

	if contact and not _.isArray(contact)	# only if we're certain which contact this matches,
		return addDeets2Contact notifications, user, contact, details, specialties, industries

	null


saveLinkedin = (details, listedDetails, user, contact, linkedin) ->

	if not linkedin
		linkedin = new models.LinkedIn
		linkedin.contact = contact
		linkedin.linkedinId = details.id
		linkedin.user = user
		if not contact
			linkedin.name = 
				firstName: details.firstName
				lastName: details.lastName
				formattedName: details.formattedName

	if details.summary and linkedin.summary isnt details.summary
		linkedin.summary = details.summary
	if details.headline and linkedin.headline isnt details.headline
		linkedin.headline = details.headline

	for detail, list of listedDetails
		if list and list.length
			for item in list
				if item and item.length
					if not linkedin[detail]
						linkedin[detail] = [item]
					else if (_.indexOf item, linkedin[detail]) < 0
						linkedin[detail].addToSet item

	linkedin.lastLink = new Date()
	linkedin.save (err) ->


addDeets2Linkedin = (user, contact, details, listedDetails) ->
	if _.isArray(contact)	# if this linkedin connection matches multiple contacts,
		contact = null		# just store the deets, without trying to match
	if contact
		models.LinkedIn.findOne {contact: contact}, (err, linkedin) ->
			throw err if err
			saveLinkedin details, listedDetails, user, contact, linkedin
	else 
		models.LinkedIn.findOne {linkedinId: details.id}, (err, linkedin) ->
			throw err if err
			saveLinkedin details, listedDetails, user, contact, linkedin


addDeets2Contact = (notifications, user, contact, details, specialties, industries) ->
	if details.positions and details.positions.length
		if not contact.company and not contact.position
			contact.company = details.positions[0].company?.name
			contact.position = details.positions[0].title
			dirtycontact = true
		else if not contact.company
			contact.company = _.select(details.positions, (p) -> p.title is contact.position)?.company?.name
			dirtycontact = true
		else if not contact.position
			contact.position = _.select(details.positions, (p) -> p.company?.name is contact.company)?.title
			dirtycontact = true

		# still no matches?
		if not contact.company
			contact.company = details.positions[0].company?.name
			dirtycontact = true
		else if not contact.position
			dirtycontact = true
			contact.position = details.positions[0].title

	if not contact.picture and details.pictureUrl
		contact.picture = details.pictureUrl
		dirtycontact = true

	if specialties and specialties.length
		addTags user, contact, 'industry', specialties
	addTags user, contact, 'industry', industries

	if (_.indexOf user._id, contact.knows) < 0
		contact.knows.addToSet user
		dirtycontact = true

	if contact.linkedin isnt details.profileid
		contact.linkedin = details.profileid
		dirtycontact = true
	
	years = calculateExperience contact, details
	if contact.yearsExperience isnt years
		contact.yearsExperience = years
		dirtycontact = true

	if dirtycontact
		contact.save (err) ->
			notifications.updateFeeds? contact
		return contact._id

	null



#
# after submitting a query on contact name, try to narrow down the results ...
#
_matchContact = (user, contacts, cb) ->
	if not contacts.length
		return cb null
	if (contacts.length > 1)
		nc = _.select contacts, (c) -> (_.indexOf user._id, c.knows) >= 0
		if nc.length
			contacts = nc
	if (contacts.length > 1)
		nc = _.select contacts, (i) -> i.addedBy is user._id
		if nc.length
			contacts = nc
	if (contacts.length > 1)
		return cb contacts				# oh dear, what a challenge: more than one? work it out later ...
	cb contacts[0]



###
#   escape a string in preparation for building a regular expression
###
REescape = (str) ->
	if not str then return ""
	str.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')


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
	rName = new RegExp('^' + REescape(name) + '$', 'i')
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
matchContact = (user, first, last, formatted, cb) ->
	name = first + ' ' + last
	matchInsensitiveContact name, (contacts) ->
		if contacts or name is formatted then _matchContact user, contacts, cb
		else matchInsensitiveContact formatted, (contacts) ->
			_matchContact user, contacts, cb


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


linker = (user, auth, notifications, fn) ->

	parturl = '/~/connections:(id,first-name,last-name,formatted-name,site-standard-profile-request)'
#
#	TODO : what if we have linkedin contacts before we ever email them?
#	if they never updated their linkedin, we'd never pick out their data ...
#
#		if user.lastlink
#			parturl += "?modified-since=#{user.lastlink}"

	# today = new Date()
	# user.lastlink = today.getTime() + today.getTimezoneOffset()*1000

	oauth = 
		consumer_key: process.env.LINKEDIN_API_KEY
		consumer_secret: process.env.LINKEDIN_API_SECRET
		token: auth.token
		token_secret: auth.secret

	getLinked parturl, oauth, (err, network) ->
		if err or not network
			return console.warn parturl + ' failed.'

		changed = []		# build an array of changed contacts to broadcast
		notifications.foundTotal? network.values.length
		countSomeFeed = 9		# only add the first few new items to the feed

		liProcess = (item, contact, cb, notYetContacts=false) ->
			getDeets item.id, contact, oauth, (err, deets) ->
				notifications.completedContact?()
				if err or not deets
					if err and err.statusCode is 403
						if notYetContacts		# was this during the second parse?
							err = null			# if so, don't report throttle
						else
							console.log "linkedin process throttled"
							console.dir err
						return fn err, changed
					else if err
						console.log "error in linkedin process"
						console.dir err
				else
					for key, val of deets		# copy profile, splitting past and present positions
						if key is 'positions'
							item[key] = _.select val.values, (p) -> p.isCurrent
							item.pastpositions = _.select val.values, (p) -> not p.isCurrent
						else
							item[key] = val

					if countSomeFeed
						countSomeFeed--
					else
						notifications.updateFeeds = null
					id = push2linkQ notifications, user, contact, item
					if id then changed.push id
				cb()

		maybeMore = []
		syncForEach network.values, (item, cb) ->
			item.profileid = profileIdFrom item
			matchContact user, item.firstName, item.lastName, item.formattedName, (contact) ->
				notifications.completedLinkedin?()
				if not contact
					maybeMore.push item
					cb()
				else
					liProcess item, contact, cb
		, ->
			if not maybeMore.length
				return fn null, changed
			syncForEach maybeMore, (item, cb) ->
				liProcess item, null, cb, true			# this true flag means we won't report throttle
			, ->
				return fn null, changed

module.exports =
	linker: linker
	matchContact: matchContact
	calculateExperience: calculateExperience

