everyauth = module.exports = require 'everyauth'
models = require './models'
_ = require 'underscore'
_s = require 'underscore.string'


everyauth.everymodule.findUserById (userId, cb)->
	models.User.findOne {_id: userId}, cb

everyauth.google.configure
	appId: process.env.GOOGLE_API_ID
	appSecret: process.env.GOOGLE_API_SECRET
	entryPath: '/authorize'
	callbackPath: '/authorized'
	authQueryParam:
		approval_prompt: 'force'
		access_type: 'offline'
	scope: [
			'https://www.googleapis.com/auth/userinfo.profile'
			'https://www.googleapis.com/auth/userinfo.email'
			'https://mail.google.com/'
			'https://www.google.com/m8/feeds'
		].join ' '

	handleAuthCallbackError: (req, res) ->
		res.redirect '/unauthorized'

	findOrCreateUser: (session, accessToken, accessTokenExtra, googleUserMetadata) ->
		console.dir googleUserMetadata
		console.dir accessToken
		console.dir accessTokenExtra
		email = googleUserMetadata.email.toLowerCase()
		models.Admin.findById 1, (err, admin)->
			throw err if err
			if admin?.domains?.length and not _.some(admin.domains, (domain)->
				_s.endsWith email, "@#{domain}"
			)
				return {}
			models.User.findOne email: email, (err, user) ->
				throw err if err
				if not user
					console.log "creating new user #{email} with #{googleUserMetadata.name}"
					user = new models.User
					user.email = email
					user.name = googleUserMetadata.name
					if googleUserMetadata.picture then user.picture = googleUserMetadata.picture
					if process.env.ADMIN_EMAIL is user.email then user.admin = true

				token = accessTokenExtra.refresh_token
				if not user.oauth		# OA2 virgin?
					console.log "no oauth on user #{email} with #{googleUserMetadata.name} : adding #{token}"
					if not user.oauth = token
						console.log "ERROR: user #{email} has no token in database, and token didnt arrive via OA2"
					if not user.name then user.name = googleUserMetadata.name			# if user was created by cIO
					if not user.picture?.length and googleUserMetadata.picture?.length
						user.picture = googleUserMetadata.picture	# but then logs in with gOA2
					console.dir "nu user oauth"
					console.dir user
					user.save (err) ->
						throw err if err
						promise.fulfill user
				else if token and user.oauth isnt token		# Update the refresh token if google gave us a new one.
					console.log "wrong token on user #{email} with #{googleUserMetadata.name} : overwriting with #{token}"
					user.oauth = token
					user.save (err) ->
						throw err if err
						promise.fulfill user
				else promise.fulfill user			# user #{email} already had correct token #{token}
		promise = @Promise()

	addToSession: (session, auth) ->
		session.user = auth.user.id

	sendResponse: (res, data) ->
		user = data.user
		if not user.id then return res.redirect '/invalid'
		# this might be good enough ...
		if user.lastParsed and user.oauth then return res.redirect '/recent'
		res.redirect '/load'


everyauth.linkedin.configure
	consumerKey: process.env.LINKEDIN_API_KEY
	consumerSecret: process.env.LINKEDIN_API_SECRET
	entryPath: '/linker'
	callbackPath: '/linked'
	handleAuthCallbackError: (req, res) ->
		#
		# TODO this doesn't seem to work. If a user cancels signing in to linkedin he gets a nasty response.
		# see https://github.com/bnoguchi/everyauth/issues/101
		#
		# if req.params.oauth_problem
		#
		res.redirect '/profile'
	findOrCreateUser: (session, accessToken, accessTokenSecret, linkedinUserMetadata) ->
		models = require './models'
		models.User.findById session.user, (err, user) ->
			throw err if err
			if user.linkedin is linkedinUserMetadata.id and user.linkedInAuth and user.linkedInAuth.secret is accessTokenSecret and user.linkedInAuth.token is accessToken then promise.fulfill user
			else
				user.linkedin = linkedinUserMetadata.id
				user.linkedInAuth =
					token: accessToken
					secret: accessTokenSecret
				user.save (err) ->
					throw err if err
					promise.fulfill user
		promise = @Promise()
	redirectPath: '/link'
everyauth.linkedin
	.requestTokenQueryParam('scope', ['r_basicprofile', 'r_fullprofile', 'r_network'].join(' '))
	.requestTokenQueryParam('fetch', ['picture-url', 'id'].join(' '))
