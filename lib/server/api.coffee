module.exports = (socket, session) ->
	_ = require 'underscore'
	models = require './models'


	socket.on 'login', (email, fn) ->
		models.User.findOne email: email, (err, user) ->
			throw err if err
			# TODO do authentication, either openID or: if user and user.password is req.body.password
			if user
				session.user = user.id
				session.save()
				return fn user.id
			fn()

	socket.on 'logout', (fn) ->
		session.destroy() # TODO This might not work right because of the way socket connections and sessions are 1:1
		return fn()

	socket.on 'signup', (email, fn) ->
		oauth = require 'oauth-gmail'
		client = oauth.createClient callbackUrl: 'http://' + process.env.HOST + '/authorized'
		client.getRequestToken email, (err, result) ->  # TODO XXX try mistyping an email and see what happens
			throw err if err
			session.authorizeData = email: email, request: result
			session.save()
			return fn result.authorizeUrl

	socket.on 'db', (data, fn) ->
		model = models[data.type]
		switch data.op
			when 'find'
				if id = data.id
					model.findById id, (err, doc) ->
						throw err if err
						return fn doc
				else if ids = data.ids
					model.find '_id': $in: ids, (err, docs) ->
						throw err if err
						return fn docs
				else if query = data.query
					model.find query, (err, docs) ->
						throw err if err
						return fn docs
				else
					model.find (err, docs) ->
						throw err if err
						return fn docs
			when 'create'
				details = data.details
				if not _.isArray details
					model.create details, (err, doc) ->
						throw err if err
						return fn doc
				else
					model.create details, (err, docs...) ->
						throw err if err
						return fn docs
			when 'save'
				# TODO use model.save() to get validators and middleware
				throw new Error 'unimplemented'
			when 'delete'
				if id = data.id
					model.findByIdAndRemove id, (err) ->
						throw err if err
						return fn()
				else if ids = data.ids
					# TODO Remove each one and call return fn() when they're ALL done
					throw new Error 'unimplemented'
				else
					throw new Error
			else
				throw new Error