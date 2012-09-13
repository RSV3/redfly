module.exports = (io, login, logout) ->
	_ = require 'underscore'
	models = require './models'


	io.sockets.on 'connection', (socket) ->
		socket.on 'login', (email, fn) ->
			# If the user has never logged in before, redirect to gmail oauth page. Otherwise, log in.
			models.User.findOne email: email, (err, user) ->
				throw err if err

				# TODO do authentication, either openID or: if user and user.password is req.body.password
				if user
					login user.id, socket
					return fn()
				else

					# TODO XXX testing, but use this code
					# user = new models.User
					# user.email = 'chris@redstar.com'
					# user.name = 'bob bobson'
					# user.oauth =
					# 	token: 'asdf'
					# 	secret: 'asdf'
					# user.save (err) ->
					# 	throw err if err
					# 	login user.id, socket
					# 	return fn()

					# oauth = require 'oauth-gmail'
					# client = oauth.createClient callbackUrl: 'http://' + process.env.HOST + '/authorized'
					# client.getRequestToken email, (err, result) ->  # TODO XXX try mistyping an email and see what happens
					# 	throw err if err
					# 	# model.session.authorizeData = email: email, request: result	# TODO XXX XXX how to save to session
					# 	return fn result.authorizeUrl

		socket.on 'logout', (fn) ->
			logout socket
			return fn()

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