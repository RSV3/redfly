_ = require 'underscore'
util = require './util'
models = require './models'
AddTags = require './addtags'


###
##	Regular Expression helpers
####

#   escape a string in preparation for building a regular expression
REescape = (str) ->
	if not str then return ""
	str.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')

# make a case-insensitive regexp from a string
REImake = (str) ->
	if not str?.replace then return null
	return new RegExp('^' + REescape(str) + '$', 'i')


addDeets2Contact = (notifications, u, c, l) ->
	if not l then return null

	if l.positions?.length
		if not c.company and not c.position
			c.company = l.companies[0]
			c.position = l.positions[0]
			dirtycontact = true
		else if not c.company
			if (i = _.indexOf(l.positions, c.position)) >= 0
				c.company = l.companies[i]
			dirtycontact = true
		else if not c.position
			if (i = _.indexOf(l.companies, c.company)) >= 0
				c.position = l.positions[i]
			dirtycontact = true
		else								# still no matches?
			if not c.company
				c.company = l.companies[0]
				dirtycontact = true
			else if not c.position
				c.position = l.positions[0]
				dirtycontact = true

	if not c.picture and l.pictureUrl
		c.picture = l.pictureUrl
		dirtycontact = true

	for eachUser in l.users
		unless _.contains c.knows, eachUser
			c.knows.addToSet eachUser
			dirtycontact = true

	tagstoadd = []
	if l.industries?.length then tagstoadd = tagstoadd.concat l.industries
	if l.specialties?.length then tagstoadd = tagstoadd.concat l.specialties
	if tagstoadd.length then AddTags u, c, 'industry', _.uniq tagstoadd

	if (_.indexOf c.knows, u._id) < 0
		c.knows.addToSet u
		dirtycontact = true

	if l.linkedinId and c.linkedinId isnt l.linkedinId
		c.linkedinId = l.linkedinId
		dirtycontact = true

	if l.publicProfileUrl and not c.linkedin
		if (i = l.publicProfileUrl.indexOf '/pub/') >= 0 then i = i+5
		else if (i = l.publicProfileUrl.indexOf '/in/') >= 0 then i = i+4
		if i>0
			c.linkedin = l.publicProfileUrl[i..]
			dirtycontact = true

	
	if l.yearsExperience and c.yearsExperience isnt l.yearsExperience
		c.yearsExperience = l.yearsExperience
		dirtycontact = true

	if dirtycontact
		c.save (err) ->
			notifications?.updateFeeds? c
		return c._id

	null


copyLI2contact = (u, c, l) ->
	addDeets2Contact null, u, c, l
	l.contact = c
	l.lastLink = new Date()
	l.save (err) ->
		if err
			console.log "ERROR copying LI2contact"
			console.dir err
			console.dir l
			console.dir c


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
			if not err and l then copyLI2contact u, c, l
			return calldone()
	else
		rNames = []
		for n in c.names		# try to match the linkedin name to any of the contact's names
			if rn = REImake(n) then rNames.push rn
		models.LinkedIn.findOne {contact:null, 'name.formattedName': $in: rNames}, (err, l) ->	# for each unmatched linkedin in the system
			if not err and l then copyLI2contact u, c, l
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

