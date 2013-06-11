_ = require 'underscore'
util = require './util'
models = require './models'
addTags = require './addtags'


###
##	Regular Expression helpers
####

#   escape a string in preparation for building a regular expression
REescape = (str) ->
	if not str then return ""
	str.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')

# make a case-insensitive regexp from a string
REImake = (str) ->
	return new RegExp('^' + REescape(str) + '$', 'i')


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
		else if contact.company = details.positions[0].company?.name	# possibly a promotion?
			dirtycontact = true
			contact.position = details.positions[0].title

	if not contact.picture and details.pictureUrl
		contact.picture = details.pictureUrl
		dirtycontact = true

	tagstoadd = []
	if industries?.length then tagstoadd = tagstoadd.concat industries
	if specialties?.length then tagstoadd = tagstoadd.concat specialties
	if tagstoadd.length then addTags user, contact, 'industry', _.uniq tagstoadd

	if (_.indexOf contact.knows, user._id) < 0
		contact.knows.addToSet user
		dirtycontact = true

	if contact.linkedin isnt details.profileid
		contact.linkedin = details.profileid
		dirtycontact = true
	
	if details.yearsExperience and contact.yearsExperience isnt details.yearsExperience
		contact.yearsExperience = details.yearsExperience
		dirtycontact = true

	if dirtycontact
		contact.save (err) ->
			notifications?.updateFeeds? contact
		return contact._id

	null


copyLI2contact = (u, c, l) ->
	details =						# in which case add the details to the matched contact
		profileid: l.linkedinId
		pictureUrl: l.pictureUrl
		yearsExperience: l.yearsExperience
		positions: [{ title: l.positions[0], company: name: l.companies[0]}]
	addDeets2Contact null, u, c, details, l.specialties, l.industries
	l.contact = c
	l.lastLink = new Date()
	l.save (err) ->


# for all linkedin records in the system that have not yet matched contacts,
# step through this list of (remaining unmatched) contacts, and try to match them.
#
# conts is the list of contacts recently parsed, not yet matched (to our own LI network)
#
# u = user
# c = contact
# l = linkedin record

findAndUpdateOtherLinkedInDataFor = (u, c, calldone) ->
	if c.linkedinId
		models.LinkedIn.findOne {contact:null, linkedinId:c.linkedinId}, (err, l) ->	# for each unmatched linkedin in the system
			if not err and l
				copyLI2contact u, c, l
			return calldone()
	else
		rNames = []
		for n in c.names		# try to match the linkedin name to any of the contact's names
			rNames.push(REImake n)
		models.LinkedIn.findOne {contact:null, 'name.formattedName': $in: rNames}, (err, l) ->	# for each unmatched linkedin in the system
			if not err and l
				copyLI2contact u, c, l
			return calldone()



#
# this module augments a contact with any matching, unconnected linkedin records
#
# these records come from users' connections which were not previously matched against contacts,
# but were stored for later reference.
#
module.exports = 
	linkLater: findAndUpdateOtherLinkedInDataFor
	addDeets2Contact: addDeets2Contact
	REImake: REImake

