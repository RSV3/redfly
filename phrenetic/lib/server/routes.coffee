module.exports = (projectRoot, app) ->

	route = (action, name, cb) ->
		app[action] "/#{name}", (req, res) ->
			console.log "#{action} /#{name}"
			console.dir req.url
			console.dir req.host
			console.dir req.xhr
			console.dir req.sessionID
			console.dir req.session
			console.dir req.cookies
			console.dir req.signedCookies
			console.log ''
		
			fn = (o)->
				res.contentType 'json'
				res.send JSON.stringify o or null
			data = if action is 'post' then req.body else req.query
			switch cb.length
				when 1 then cb fn
				when 2 then cb req.session, fn
				when 3 then cb data, req.session, fn
				when 4 then cb req.params, data, req.session, fn
				else
					throw new Error


	route 'get', 'session', (session, fn)->
		fn session

	route 'post', 'logout', (session, fn)->
		session.user = null
		session.destroy()
		session.save()
		fn()

	require("#{projectRoot}/lib/server/routes") route

