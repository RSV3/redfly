everyauth = module.exports = require 'everyauth'


everyauth.google.configure
	appId: process.env.GOOGLE_API_ID
	appSecret: process.env.GOOGLE_API_SECRET
	entryPath: '/authorize'
	callbackPath: '/authorized'
	authQueryParam:
		access_type: 'offline'
		approval_prompt: 'auto'
	scope: [
			'https://www.googleapis.com/auth/userinfo.profile'
			'https://www.googleapis.com/auth/userinfo.email'
			'https://mail.google.com/'
			'https://www.google.com/m8/feeds'
		].join ' '
	handleAuthCallbackError: (req, res) ->
		res.redirect '/unauthorized'
	findOrCreateUser: (session, accessToken, accessTokenExtra, googleUserMetadata) ->
		_s = require 'underscore.string'
		models = require './models'

		email = googleUserMetadata.email.toLowerCase()
		if not _s.endsWith email, "@#{process.env.ORGANISATION_DOMAIN}"
			return {}
		models.User.findOne email: email, (err, user) ->
			throw err if err
			token = accessTokenExtra.refresh_token
			if user
				# TEMPORARY ########## have to save stuff for existing users who signed up before the switch to oauth2
				if not user.oauth
					user.name = googleUserMetadata.name
					if picture = googleUserMetadata.picture
						user.picture = picture
					user.oauth = token
					user.save (err) ->
						throw err if err
						promise.fulfill user
				# END TEMPORARY ###########
				# Update the refresh token if google gave us a new one.
				else if user.oauth isnt token
					user.oauth = token
					user.save (err) ->
						throw err if err
						promise.fulfill user
				else
					promise.fulfill user
			else
				user = new models.User
				user.email = email
				user.name = googleUserMetadata.name
				if picture = googleUserMetadata.picture
					user.picture = picture
				user.oauth = token
				user.save (err) ->
					throw err if err
					promise.fulfill user
		promise = @Promise()
	addToSession: (session, auth) ->
		session.user = auth.user.id
	sendResponse: (res, data) ->
		user = data.user
		if not user.id
			return res.redirect '/invalid'
		if not user.lastParsed
			return res.redirect '/load'
		res.redirect '/profile'


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
			if not user.linkedin or (user.linkedin isnt linkedinUserMetadata.id)
				user.linkedin = linkedinUserMetadata.id
				user.save (err) ->
					throw err if err
					promise.fulfill user
			else
				promise.fulfill user
		promise = @Promise()
	addToSession: (session, auth) ->
		session.linkedinAuth =
			token: auth.accessToken
			secret: auth.accessTokenSecret
	redirectPath: '/link'
everyauth.linkedin
	.requestTokenQueryParam('scope', ['r_basicprofile', 'r_fullprofile', 'r_network'].join(' '))
	.requestTokenQueryParam('fetch', ['picture-url', 'id'].join(' '))
