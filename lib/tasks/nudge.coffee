models = require '../server/models'

models.User.find (err, users) ->
	throw err if err

	# TODO sucky
	app = require('express')()
	path = require 'path'
	root = path.dirname path.dirname __dirname
	app.configure ->
		app.set 'views', root + '/views'
		app.set 'view engine', 'jade'
		app.locals.pretty = process.env.NODE_ENV is 'development'

	step = require 'step'
	step ->
			for user in users
				require('../server/parser') app, user, null, @parallel()
			return undefined
		, (err) ->
			throw err if err
			require('../server/db').disconnect()