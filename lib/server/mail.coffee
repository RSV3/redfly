# TO-DO icky
path = require 'path'
projectRoot = path.dirname path.dirname __dirname

mail = module.exports = require('phrenetic/lib/server/mail') projectRoot


from = "#{process.env.ORGANISATION_CONTACT} <#{process.env.ORGANISATION_EMAIL}>"

# mail.sendWelcome: (to, cb) ->
# 	mail.sendTemplate 'welcome',
# 		to: to
# 		subject: 'Thank you for joining Redfly!'
# 		# Need to add 'title:' here
# 	, cb


mail.sendNudge = (user, contacts, cb) ->
	_ = require 'underscore'
	_s = require 'underscore.string'
	util = require './util'

	# TO-DO duplicates some logic in the client models. Maybe put said logic in a common place.
	names = []
	for contact in contacts
		if name = _.first(contact.names)
			names.push name
		else
			email = _.first(contact.emails)
			splitted = email.split '@'
			domain = _.first _.last(splitted).split('.')
			names.push _.first(splitted) + ' [' + domain + ']'
	nicknames = (util.nickname(_.first(contact.names), _.first(contact.emails)) for contact in contacts)
	
	mail.sendTemplate 'nudge',
		to: user.email
		from: from
		subject: 'Tell me more about ' + nicknames.join(', ') + '...'	# TO-DO Use _s.toSentenceSerial whenever it becomes available.
		title: 'Hi ' + user.name + '!'
		names: names
	, cb


mail.sendNewsletter = (user, cb) ->
	logic = require './logic'
	require('step') ->
		logic.summaryContacts @parallel()
		logic.summaryTags @parallel()
		logic.summaryNotes @parallel()
		return undefined
	, (err, numContacts, numTags, numNotes) ->
		throw err if err
		mail.sendTemplate 'newsletter',
			to: user.email
			from: from
			subject: 'On the Health and Well-Being of Redfly'
			title: 'It\'s been a big week!'
			contactsQueued: numContacts
			tagsCreated: numTags
			notesAuthored: numNotes
		, cb


mail.requestIntro = (userfrom, userto, contact, url, cb) ->
	tonick = userto.name.split(' ')[0]
	fromnick = userfrom.name.split(' ')[0]
	contactnick = contact.names[0]?.split(' ')[0]
	if not contactnick or not contactnick.length
		contactnick = contact.emails[0]
	contactname = contact.names[0]
	if not contactname or not contactname.length
		contactname = contact.emails.firstObject
	mail.sendTemplate 'intro',
		#to: "#{userto.get('canonicalName')} <#{userto.get('email')}>"
		#from: userfrom.get('email')
		to: "#{userto.name} <#{userto.email}>"
		from: userfrom.email
		subject: "Redfly Intro: You know #{contactnick}, right?"
		title: "Hi #{tonick}"
		nick: contactnick
		name: contactname
		tonick: tonick
		fromnick: fromnick
		url: url
	, cb

