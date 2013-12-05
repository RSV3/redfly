auth = require './auth'
models = require './models'

everyauth = require 'everyauth'

authWithHint = (next, hint)->
	opts =
		access_type: 'offline'
		approval_prompt: if hint then 'auto' else 'force'
	if hint then opts.login_hint = hint
	everyauth.google.authQueryParam opts
	next()

module.exports = (app) ->
	app.use auth.middleware()
	app.use (req, res, next)->
		if req.session?.user?.length then return next() 	# already logged in? well, thatsok.
		lastlogin = req.cookies?.lastlogin
		if not lastlogin?.length
			return authWithHint next
		models.User.findById lastlogin, (err, user) ->
			if err or not user?.oauth
				console.log "couldn't login with #{lastlogin} : #{user?.email} / #{user?.oauth}"
				console.dir err
				return authWithHint next
			return authWithHint next, user.email
