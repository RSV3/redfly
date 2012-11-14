models = require '../server/models'

models.User.find (err, users) ->
	throw err if err

	notifications =
		error: (message) ->
			throw new Error message

	# TODO sucky
	app = require('express')()
	path = require 'path'
	root = path.dirname path.dirname __dirname
	app.configure ->
		app.set 'views', root + '/views'
		app.set 'view engine', 'jade'
		app.locals.pretty = process.env.NODE_ENV is 'development'

	for user in users
		require('../server/parser') app, user, notifications, (err) ->
			throw err if err
