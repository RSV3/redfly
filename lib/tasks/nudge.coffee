moment = require 'moment'
if moment().format('dddd') isnt process.env.NUDGE_DAY
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
