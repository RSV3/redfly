_ = require 'underscore'
moment = require 'moment'
if not _.contains(process.env.NUDGE_DAYS.split(' '), moment().format('dddd'))
	process.exit()

models = require '../server/models'

models.User.find (err, users) ->
	throw err if err

	require('step') ->
		for user in users
			require('../server/parser') user, null, @parallel()
		return undefined
	, (err) ->
		throw err if err
		require('phrenetic/lib/server/services').close()
