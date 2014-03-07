module.exports = (projectRoot, app) ->

	route = (action, name, cb) ->
		app[action] "/#{name}", (req, res) ->
			fn = ->
				switch arguments.length
					when 0 then o = null
					when 1 then o = arguments[0]
					else o = Array.prototype.slice.call arguments
				res.contentType 'json'
				res.send JSON.stringify o
			if action is 'post' then data = req.body
			else
				data = req.query	# GET data comes in query params
				delete data._		# ajax uses ?_=1234567 for no-cache: discard it.
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

