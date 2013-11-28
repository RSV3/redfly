# TO-DO icky
path = require 'path'
projectRoot = path.dirname path.dirname __dirname

Mail = module.exports = require('phrenetic/lib/server/mail') projectRoot
Logic = require './logic'


From = "#{process.env.ORGANISATION_CONTACT} <#{process.env.ORGANISATION_EMAIL}>"


Mail.sendNudge = (user, contacts, cb) ->		# note we're now ignoring the 'contacts' list,
	return mail.sendNewNewsletter user, cb		# cos we have a more complicated way to work out classifies


Mail.sendNewNewsletter = (user, cb) ->
	require('step') ->
		Logic.countConts @parallel()					# total in the system
		Logic.myConts user.get('id'), @parallel()		# total this user this week
		Logic.recentConts @parallel()					# short list of recent contacts in system
		Logic.recentOrgs @parallel()					# short list of recent orgs in system
		Logic.classifySome user.get('id'), @parallel()					# list of classifies for this user
		return undefined
	, (err, numContacts, numMyContacts, recentContacts, recentOrgs, some2Class) ->
		if err then return cb err

		if some2Class?.length is 1 then classStr = "one new contact"
		else if some2Class?.length > 10
			classStr = "lots of new contacts"
			some2Class = some2Class[0..10]
		else if some2Class?.length > 1 then classStr = "#{some2Class.length} new contacts"
		else classStr = null
		mySubj = "Get connected to cool people"
		headstrip = "Meet new connections"
		if recentOrgs?.length
			mySubj += " at #{recentOrgs[0].company}"
			headstrip += " from #{recentOrgs[0].company}"
			if recentOrgs?.length > 1
				mySubj += ", #{recentOrgs[1].company}"
				headstrip += ", #{recentOrgs[1].company}"
			if recentOrgs?.length > 2
				mySubj += ", #{recentOrgs[2].company}"
				headstrip += ", #{recentOrgs[2].company}"
		templateObj = 
			org: process.env.ORGANISATION_TITLE
			title: "Hi #{user.name}!"
			to: user.email
			from: From
			subject: mySubj
			numContacts: numContacts
			numMyContacts: numMyContacts
			recentContacts: recentContacts[0..12]
			recentOrgs: recentOrgs
			some2Class: some2Class
			classStr: classStr
			headstrip: headstrip
		Mail.sendTemplate 'newnewsletter', templateObj, cb



Mail.sendNewsletter = (user, cb) ->
	return Mail.sendNewNewsletter user, cb


Mail.requestIntro = (userfrom, userto, contact, url, cb) ->
	tonick = userto.name.split(' ')[0]
	fromnick = userfrom.name.split(' ')[0]
	contactnick = contact.names[0]?.split(' ')[0]
	if not contactnick or not contactnick.length
		contactnick = contact.emails[0]
	contactname = contact.names[0]
	if not contactname or not contactname.length
		contactname = contact.emails.firstObject
	Mail.sendTemplate 'intro',
		#to: "#{userto.get('canonicalName')} <#{userto.get('email')}>"
		#from: userfrom.get('email')
		to: "#{userto.name} <#{userto.email}>"
		from: userfrom.email
		cc: userfrom.email
		subject: "Redfly Intro: You know #{contactnick}, right?"
		title: "Hi #{tonick}"
		nick: contactnick
		name: contactname
		tonick: tonick
		fromnick: fromnick
		url: url
	, cb


Mail.sendRequests = (user, uRequests, oRequests, cb) ->
	if not uRequests.length and not oRequests.length then return cb()
	require('step') ->
		Logic.countConts @parallel()					# total in the system
		return undefined
	, (err, numContacts)->
		templateObj = 
			org: process.env.ORGANISATION_TITLE
			title: "Hi #{user.name}!"
			to: user.email
			from: From
			subject: "Recent requests for contacts"
			headstrip: "help colleagues make useful connections"
			urgentRequests: uRequests
			otherRequests: oRequests
			numContacts: numContacts
		Mail.sendTemplate 'requests', templateObj, cb


Mail.sendResponses = (user, requests, cb) ->
	if not requests.length then return cb()
	require('step') ->
		Logic.countConts @parallel()					# total in the system
		return undefined
	, (err, numContacts)->
		templateObj = 
			org: process.env.ORGANISATION_TITLE
			title: "Hi #{user.name}!"
			to: user.email
			from: From
			subject: "Recent responses to your request for contacts"
			headstrip: "your colleagues suggest these useful connections"
			id: user._id
			requests: requests
			numContacts: numContacts
		Mail.sendTemplate 'responses', templateObj, cb


