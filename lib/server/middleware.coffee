auth = require './auth'
models = require './models'

everyauth = require 'everyauth'

module.exports = (app) ->
	app.use auth.middleware()
	app.use (req, res, next)->
		if req.session?.user?.length then return next() 	# already logged in? well, thatsok.
		console.dir req.cookies
		lastlogin = req.cookies?.lastlogin
		if not lastlogin?.length then return next()
		models.User.findById lastlogin, (err, user) ->
			if err or not user?.oauth
				console.log "couldnt login with #{lastlogin}"
				console.dir err
				console.dir user
				return next()
			everyauth.google.authQueryParam
				login_hint: user.email		# otherwise we might not have a refresh token. 
				approval_prompt: 'auto'		# otherwise we might not have a refresh token. 
				access_type: 'offline'		# what we really need tho is some way to set the login_hint option ...
			next()
