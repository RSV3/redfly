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
	url = "http://api.linkedin.com/v1/people#{partial}?format=json"
	request.get
		url: url
		oauth: oa
		json: true
	, (error, response, body) ->
		if not error and response.statusCode is 200
			cb body
		else
			console.log "got error #{error} and #{response.statusCode} looking for #{partial}"
			console.dir response.body
			console.dir oa
			cb null


getDeets = (id, oa, cb) ->
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


###
add new contact details to the queue for this user
###
push2linkQ = (user, contact, details) ->
	if details.specialties
		specialties = details.specialties.split(',')
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
	addDeets2Contact user, contact, details, specialties, industries


addDeets2Linkedin = (user, contact, details, listedDetails) ->
	models.LinkedIn.findOne {contact: contact}, (err, linkedin) ->
		throw err if err
		altered = false
		if not linkedin
			linkedin = new models.LinkedIn
			linkedin.contact = contact
			linkedin.liid = details.id
			altered = true

		if details.summary and linkedin.summary isnt details.summary
			linkedin.summary = details.summary
			altered = true
		if details.headline and linkedin.headline isnt details.headline
			linkedin.headline = details.headline
			altered = true

		for detail, list of listedDetails
			if list and list.length
				for item in list
					if not linkedin[detail]
						linkedin[detail] = [item]
						altered = true
					else if (_.indexOf item, linkedin[detail]) < 0
						linkedin[detail].addToSet item
						altered = true

		if altered
			linkedin.save (err) ->

addDeets2Contact = (user, contact, details, specialties, industries) ->
	if details.positions and details.positions.length
		if not contact.company and not contact.position
			contact.company = details.positions[0].company.name
			contact.position = details.positions[0].title
			dirtycontact = true
		else if not contact.company
			contact.company = _.select(details.positions, (p) -> p.position is contact.title)?.company.name
			dirtycontact = true
		else if not contact.position
			contact.position = _.select(details.positions, (p) -> p.company.name is contact.company)?.title
			dirtycontact = true

		# still no matches?
		if not contact.company
			contact.company = details.positions[0].company.name
			dirtycontact = true
		else if not contact.position
			dirtycontact = true
			contact.position = details.positions[0].title

	if not contact.picture and details.pictureUrl
		contact.picture = details.pictureUrl
		dirtycontact = true

	if specialties and specialties.length
		addTags user, contact, 'redstar', specialties
	addTags user, contact, 'industry', industries

	if (_.indexOf user._id, contact.knows) < 0
		contact.knows.addToSet user
		dirtycontact = true

	linklink = "http://www.linkedin.com/profile/view?id=#{details.id}"
	if contact.linkedin isnt linklink
		contact.linkedin = linklink
		dirtycontact = true
	
	if dirtycontact
		contact.save (err) ->



#
# after submitting a query on contact name, try to narrow down the results ...
#
_matchContact = (contacts, cb) ->
	if not contacts.length
		cb null
	if (contacts.length > 1)
		nc = _.select contacts, (c) -> (_.indexOf user._id, c.knows) >= 0
		if nc.length
			contacts = nc
	if (contacts.length > 1)
		nc = _.select contacts, (i) -> i.addedBy is user._id
		if nc.length
			contacts = nc
	if (contacts.length == 1)
		cb contacts[0]
	cb contacts				# oh dear, what a challenge: more than one? work it out later ...



###
#   escape a string in preparation for building a regular expression
###
REescape = (str) ->
	if not str return ""
	str.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')


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
	name = "#{first} #{last}"
	r_name = new RegExp('^'+REescape(name)+'$', "i")
	models.Contact.find {names: r_name}, (err, contacts) ->
		console.log "err: #{err}" if err
		if not contacts.length and formatted and not formatted?.match(r_name)
			r_name = new RegExp('^'+REescape(formatted)+'$', "i")
			models.Contact.find {names: r_name}, (err, contacts) ->
				console.log "err: #{err}" if err
				_matchContact contacts, cb
		else
			_matchContact contacts, cb



module.exports = (app, user, info, notifications, fn) ->

	linker = (app, user, info, notifications, fn) ->

		parturl = '/~/connections:(id,first-name,last-name,formatted-name)'
#
#	TODO : what if we have linkedin contacts before we ever email them?
#	if they never updated their linkedin, we'd never pick out their data ...
#
#		if user.lastlink
#			parturl += "?modified-since=#{user.lastlink}"

		today = new Date()
		user.lastlink = today.getTime() + today.getTimezoneOffset()*1000

		oauth = 
			consumer_key: process.env.LINKEDIN_API_KEY
			consumer_secret: process.env.LINKEDIN_API_SECRET
			token: info.token
			token_secret: info.secret

		getLinked parturl, oauth, (network) ->
			if not network
				console.log "#{parturl} failed"
			if network
				notifications.foundTotal? network._total
				syncForEach network.values, (item, cb) ->
					notifications.completedEmail?()
					matchContact user, item.firstName, item.lastName, item.formattedName, (contact) ->
						if not contact
							cb()
						else if _.isArray contact
							"found multiple contacts matching #{item.firstName} #{item.lastName}"
							cb()
						else
							getDeets item.id, oauth, (deets) ->
								for key, val of deets
									if key is 'positions'
										item[key] = _.select val.values, (p) -> p.isCurrent
									else
										item[key] = val
								push2linkQ user, contact, item
								cb()
				, () ->
					# is there any further user interaction necessary?
					fn()

	linker app, user, info, notifications, fn
