validators = require('validator').validators
_ = require 'underscore'
_s = require 'underscore.string'
ContextIO = require 'contextio'
mimelib = require 'mimelib'
moment = require 'moment'

util = require './util'
Models = require './models'


contextConnect = (user, blacklist, domains, cb)->
	ctxioClient = new ContextIO.Client {
		key: process.env.CONTEXTIO_KEY
		secret: process.env.CONTEXTIO_SECRET }
	# unlike imap, contextio doesnt need to keep authorising each user, so long as we have their ID
	# https://api.context.io/2.0/accounts
	ctxioClient.accounts().get {email:user.email}, (err, account) ->
		if err or not account then return cb err, null
		account = account?.body
		if account?.length then account = account[0]
		# session.id = account.id # wtf? don't think this achieves anything ...
		cb null,
			CIO:ctxioClient
			id:account.id
			blacklist:blacklist
			domains:domains			# return CIO server as attribute on mbox session

clearOauthOnErr = (user)->
	Models.User.update {_id:user.id}, $set:oauth:null, (err)->
		if not err then return
		console.log "clearing oauth for #{user.id}"
		console.dir err

imapConnect = (user, blacklist, domains, cb)->
	generator = require('xoauth2').createXOAuth2Generator
		user: user.email
		clientId: process.env.GOOGLE_API_ID
		clientSecret: process.env.GOOGLE_API_SECRET
		refreshToken: user.oauth
	generator.getToken (err, token) ->
		if err
			console.log "generator.getToken #{token} for #{user.email}"
			console.dir err
			clearOauthOnErr user
			return cb err, null
		server = new require('imap').ImapConnection
			host: 'imap.gmail.com'
			port: 993
			secure: true
			xoauth2: token
		server.connect (err) ->
			if err
				console.dir err
				clearOauthOnErr user
				return cb new Error 'Problem connecting to mail.'
			server.getBoxes (err, boxen)->
				if err
					console.warn err
					return cb new Error 'Problem listing mailbox folders.'
				doOpenBox = (name)->
					server.openBox name, true, (err, box) ->
						if err
							console.warn err
							return cb new Error 'Problem opening mailbox.'
						return cb null,
							IMAP:server
							blacklist:blacklist
							domains: domains		# return IMAP server as attribute on mbox session
				for own bname, box of boxen
					if box.children
						for own cname, child of box.children
							if cname.match /sent.*/i
								return doOpenBox "#{bname}#{box.delimiter}#{cname}"
				for own bname, box of boxen
					if bname.match /sent.*/i
						return doOpenBox bname
				return cb new Error "couldn't find sent folder to open in mailbox."


imapSearch = (session, user, cb)->
	criteria = [] #'FROM', user.email]]
	previous = user.lastParsed or moment().subtract(30, 'days').toDate()
	criteria.unshift ['SENTSINCE', previous]
	console.log '' # DEBUG
	console.dir criteria # DEBUG
	session.IMAP.search criteria, cb

contextSearch = (session, user, cb)->
	options = limit:600, folder:'[Gmail]/Sent Mail' #, from:user.email
	if user.lastParsed then options.date_after = user.lastParsed.getTime()/1000
	m = session.CIO.accounts(session.id)?.messages()
	if not m then return cb -1, null
	m.get options, (err, results)->
		cb err, results?.body


# Only added people outside our domain as contacts
# exclude junk like "undisclosed recipients", and exclude yourself.
_acceptableContact = (user, name, email, excludes, blacklist)->
	return (validators.isEmail email) and (email isnt user.email) and
		(_.last(email.split '@') not in blacklist.domains) and
		(name not in blacklist.names) and
		(not _.some blacklist.emails, (e)-> e is email or email.match(new RegExp(e))) and
		(not excludes?.names or (name not in excludes.names)) and
		(not excludes?.emails or (email not in excludes.emails))

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
		if _.contains session.domains, _.last msg.addresses.from.email.split('@')
			for to in msg.addresses.to
				if to
					email = util.trim to.email?.toLowerCase()
					name = _normaliseName to.name
					if not email?.length and validators.isEmail name
						email = name
						name = null
					if _acceptableContact user, name, email, session.excludes, session.blacklist
						newmails.push
							subject: msg.subject
							sent: new Date(1000*msg.date)
							recipientEmail: email
							recipientName: name
		cb newmails
	finish()

eachImapMsg = (session, user, results, finish, cb) ->
	session.IMAP.fetch results, {
		headers: ['from', 'to', 'subject', 'date']
		cb: (fetch) ->
			fetch.on 'message', (msg)->
				msg.on 'headers', (headers)->
					newmails = []
					from = mimelib.parseAddresses(headers.from?[0])[0].address
					if from and _.contains session.domains, _.last from.split '@'
						for to in mimelib.parseAddresses headers.to?[0]
							if to
								email = util.trim to.address?.toLowerCase()
								name = _normaliseName to.name
								if not email?.length and validators.isEmail name
									email = name
									name = null
								if _acceptableContact user, name, email, session.excludes, session.blacklist
									newmails.push
										subject: headers.subject?[0]
										sent: new Date headers.date?[0]
										recipientEmail: email
										recipientName: name
					cb newmails
	},->
		session.IMAP.logout()
		finish()

imapAuth: (user, cb) ->
	# TODO

contextAuth: (user, cb) ->
	# TODO

cIOcreate = (data, cb)->
	cio = new ContextIO.Client {
		key: process.env.CONTEXTIO_KEY
		secret: process.env.CONTEXTIO_SECRET }
	o = {
		email: data.email
		password: data.password
		username: data.name or data.email		# TODO usually these will be same, but should be overridable
		use_ssl: data.ssl or process.env.CONTEXTIO_SSL		# TODO these should all be defaults overridable on client
		server: data.server or process.env.CONTEXTIO_SERVER	# TODO these should all be defaults overridable on client
		port: data.port or process.env.CONTEXTIO_PORT		# TODO these should all be defaults overridable on client
		type:'IMAP'
	}
	cio.accounts().post o, (err, account) ->
		if err or not account or account.body?.type is 'error' then return cb err:'email'
		if not account.body?.success then cb err:'password'
		account = account?.body
		Models.Admin.findById 1, (err, admin)->
			throw err if err
			if admin?.authdomains?.length and not _.some(admin.authdomains, (domain)->
				return _s.endsWith data.email, "@#{domain}"
			) and not _.contains(admin.whitelistemails, data.email)
				console.log "ERR: login email #{data.email} doesn't match domains"
				console.dir admin.authdomains
				return cb err:'email'
			return cb account


# common logic to decide whether to use google (preferred if available) or contextio (only if valid)
googOrCio = (user, goog, cio, cb, action)->
	errmsg = null
	if process.env.GOOGLE_API_ID 
		if user.oauth then return goog()
		errmsg = "#{action} ERROR: google oauth unavailable, "
	if process.env.CONTEXTIO_KEY 
		if user.cIO and user.cIO.hash and not user.cIO.expired then return cio()
		errmsg = "#{errmsg} ERROR: cIO unavailable or expired, #{action}"
	if not errmsg then errmsg = "#{action} ERROR: no mailbox option (cio, goog) to #{action}"
	console.log errmsg
	cb -1, {status:'failure', reason:errmsg}

module.exports =
	connect: (user, cb) ->
		Models.Admin.findById 1, (err, admin) ->
			blacklist = {domains:admin.blacklistdomains, names:admin.blacklistnames, emails:admin.blacklistemails}
			if not admin.userstoo then blacklist.domains = blacklist.domains.concat(admin.domains)
			googOrCio user, ->
				imapConnect user, blacklist, admin.domains, cb
			, ->
				contextConnect user, blacklist, admin.domains, cb
			, cb, "connect"
	auth: (user, cb) ->
		googOrCio user, ->
			imapAuth user, cb
		, ->
			contextAuth user, cb
		, cb, "auth"
	search: (mbSession, user, cb) ->
		# if we got this far, it's really happening:
		# so we'll need a list of excludes (contacts skipped forever)
		Models.Exclude.find(user: user._id).populate('contact').exec (err, excludes) ->
			if err then console.dir err
			else
				excludes = _.map excludes, (x)->
					{name:x.contact?.names or x.get('name'), email:x.contact?.emails or x.get('email')}
				mbSession.excludes =
					names: _.compact _.flatten _.pluck excludes, 'name'
					emails: _.compact _.flatten _.pluck excludes, 'email'
				excludes = null
			googOrCio user, ->
				imapSearch mbSession, user, cb
			, ->
				contextSearch mbSession, user, cb
			, cb, "search"
	eachMsg: (mbSession, user, results, finish, cb) ->
		googOrCio user, ->
			eachImapMsg mbSession, user, results, finish, cb
		, ->
			eachContextMsg mbSession, user, results, finish, cb
		, cb, "iterate over messages"
	create: cIOcreate


