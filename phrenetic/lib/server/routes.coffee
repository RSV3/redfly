module.exports = (projectRoot, app) ->

	route = (name, cb) ->
		app.io.route name, (req) ->
			switch cb.length
				when 1 then cb req.io.respond
				when 2 then cb req.data, req.io.respond
				when 3 then cb req.data, req.io, req.io.respond
				when 4 then cb req.data, req.io, req.session, req.io.respond
				else
					throw new Error


	route 'session', (data, io, session, fn) ->
		fn session

	route 'logout', (data, io, session, fn) ->
		session.user = null
		session.destroy()
		session.save()
		fn()


	require(projectRoot + '/lib/server/routes') app, route
