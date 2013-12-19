auth = require './auth'
models = require './models'

everyauth = require 'everyauth'

authWithHint = (next, hint)->
	opts =
		access_type: 'offline'
		approval_prompt: if hint then 'auto' else 'force'
		login_hint: if hint then hint else null
		scope: [
				'https://www.googleapis.com/auth/userinfo.profile'
				'https://www.googleapis.com/auth/userinfo.email'
				'https://mail.google.com/'
				'https://www.google.com/m8/feeds'
			].join ' '
	console.log ""
	console.log "opts from authWithHint"
	console.dir opts
	console.log ""
	everyauth.google.authQueryParam opts
	next()

module.exports = (app) ->
	app.use (req, res, next)->
		if req.session?.user?.length
			console.log ""
			console.log "already logged in:"
			console.dir req.session.user
			console.log ""
			return next() 	# already logged in? well, thatsok.
		lastlogin = req.cookies?.lastlogin
		if not lastlogin?.length then return authWithHint next
		models.User.findById lastlogin, (err, user) ->
			if err or not user?.oauth
				console.log "couldn't login with #{lastlogin} : #{user?.email} / #{user?.oauth}"
				console.dir err
				return authWithHint next
			return authWithHint next, user.email
	app.use auth.middleware()
