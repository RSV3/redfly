auth = require './auth'
models = require './models'

everyauth = require 'everyauth'

module.exports = (app) ->
	app.use auth.middleware()
	app.use (req, res, next)->
		if not req.session?.user?.length then return next() 
		models.User.findById req.session.user, (err, user) ->
			if err or not user then return next()
			everyauth.google.authQueryParam		# if there's no idea who, we need to force approval in authorisation,
				approval_prompt: 'force'		# otherwise we might not have a refresh token. 
				access_type: 'offline'		# what we really need tho is some way to set the login_hint option ...
			next()
