_ = require 'underscore'
moment = require 'moment'
#if not _.contains(process.env.NUDGE_DAYS.split(' '), moment().format('dddd'))
#	process.exit()

models = require '../server/models'

operate = (user, cb)->
	try
		require('../server/parser') user, null, (err, contacts)->
			require('../server/linker') user, user.linkedInAuth, null, contacts, cb
	catch err
		console.log "error in nudge parse"
		console.dir err

eachDoc = (docs) ->
	if not docs.length then return require('phrenetic/lib/server/services').close()
	doc = docs.pop()
	operate doc, ()-> eachDoc docs

models.User.find (err, users) ->
	throw err if err
	eachDoc users
