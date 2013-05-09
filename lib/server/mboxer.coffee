util = require './util'
models = require './models'
validators = require('validator').validators
_ = require 'underscore'
ContextIO = require('contextio');


contextConnect = (user, cb)->
	ctxioClient = new ContextIO.Client {
		key: process.env.CONTEXTIO_KEY
		secret: process.env.CONTEXTIO_SECRET }
	# unlike imap, contextio doesnt need to keep authorising each user, so long as we have their ID
	# https://api.context.io/2.0/accounts
	ctxioClient.accounts().get {email:user.email}, (err, account) ->
		if err or not account then return cb err, null
		account = account?.body
		if account?.length then account = account[0]
		cb null, { CIO: ctxioClient, id: account.id }	# return CIO server as attribute on mbox session

imapConnect = (user, cb)->
	generator = require('xoauth2').createXOAuth2Generator
		user: user.email
		clientId: process.env.GOOGLE_API_ID
		clientSecret: process.env.GOOGLE_API_SECRET
		refreshToken: user.oauth
	generator.getToken (err, token) ->
		if err
			console.log "generator.getToken #{token} for #{user.email}"
			console.warn err
			return cb err, null
		server = new require('imap-jtnt-xoa2').ImapConnection
			host: 'imap.gmail.com'
			port: 993
			secure: true
			xoauth2: token
		server.connect (err) ->
			if err
				console.dir err
				return cb new Error 'Problem connecting to mail.'
			server.openBox '[Gmail]/All Mail', true, (err, box) ->
				if err
					console.warn err
					return cb new Error 'Problem opening mailbox.'
				return cb null, { IMAP: server }	# return IMAP server as attribute on mbox session


imapSearch = (session, user, cb)->
	criteria = [['FROM', user.email]]
	if previous = user.lastParsed
		criteria.unshift ['SINCE', previous]
	session.IMAP.search criteria, cb

contextSearch = (session, user, cb)->
	options = from:user.email, limit:600, folder:'[Gmail]/Sent Mail'
	if user.lastParsed then options.date_after = user.lastParsed.getTime()/1000
	session.CIO.accounts(session.id).messages().get options, (err, results)->
		cb err, results?.body


# Only added people outside our domain as contacts
# exclude junk like "undisclosed recipients", and exclude yourself.
_acceptableContact = (user, name, email, excludes)->
	blacklist = require '../blacklist'
	return (validators.isEmail email) and (email isnt user.email) and
			(_.last(email.split('@')) not in blacklist.domains) and
			(name not in blacklist.names) and
			(email not in blacklist.emails) and
			(name not in _.pluck(excludes, 'name')) and
			(email not in _.pluck(excludes, 'email'))

# make sure the name isn't just an email address, then tidy it up
_normaliseName = (name)->
	if typeof name is 'object'
		return "#{name.first} #{name.last}"
	junkChars = ' \'",<>'
	name = util.trim name, junkChars
	if not name or not name.length then return null
	comma = name.indexOf ','
	if comma isnt -1
		name = name[comma + 1..] + ' ' + name[...comma]
		name = util.trim name, junkChars	# Trim the name again in case the swap revealed more junk
	return name


eachContextMsg = (session, user, results, finish, cb) ->
	if not results then return finish()
	while results.length
		msg = results.pop()
		newmails = []
		for to in msg.addresses.to
			email = util.trim to.email.toLowerCase()
			name = _normaliseName to.name
			if not email?.length and validators.isEmail name
				email = name
				name = null
			if _acceptableContact user, name, email, session.excludes
				newmails.push
					subject: msg.subject
					sent: new Date 1000*msg.date
					recipientEmail: email
					recipientName: name
		cb newmails
	finish()

eachImapMsg = (session, user, results, finish, cb) ->
	fetch = session.IMAP.fetch results,
		request:
			headers: ['from', 'to', 'subject', 'date']
	fetch.on 'end', ->
		session.IMAP.logout()
		finish()
	fetch.on 'message', (msg) ->
		msg.on 'end', ->
			newmails = []
			for to in require('mimelib').parseAddresses msg.headers.to?[0]
				email = util.trim to.address.toLowerCase()
				name = _normaliseName to.name
				if not email?.length and validators.isEmail name
					email = name
					name = null
				if _acceptableContact user, name, email, session.excludes
					newmails.push
						subject: msg.headers.subject?[0]
						sent: new Date msg.headers.date?[0]
						recipientEmail: email
						recipientName: name
			cb newmails

imapAuth: (user, cb) ->
	# TODO

contextAuth: (user, cb) ->
	# TODO

module.exports =
	connect: (user, cb) ->
		if process.env.CONTEXTIO_KEY then return contextConnect user, cb
		else return imapConnect user, cb
	auth: (user, cb) ->
		if process.env.CONTEXTIO_KEY then return contextAuth user, cb
		else return imapAuth user, cb
	search: (mbSession, user, cb) ->
		# if we got this far, it's really happening:
		# so we'll need a list of excludes (contacts skipped forever)
		models.Exclude.find {user: user._id}, (err, excludes) ->
			if err then console.dir err
			else mbSession.excludes = excludes
			if process.env.CONTEXTIO_KEY then return contextSearch mbSession, user, cb
			else return imapSearch mbSession, user, cb
	eachMsg: (mbSession, user, results, finish, cb) ->
		if process.env.CONTEXTIO_KEY then return eachContextMsg mbSession, user, results, finish, cb
		else return eachImapMsg mbSession, user, results, finish, cb


