succinct_manual = (process.argv[3] is 'manual')
if not succinct_manual and not require('underscore').contains(process.env.NUDGE_DAYS.split(' '), require('moment')().format('dddd'))
	process.exit()

eachLink = (user, cb)->
	try require('../server/linker') user, null, cb
	catch err
		console.log "error in nudge link for #{user.email}"
		console.dir err
		cb()

eachParse = (user, cb)->
	console.log "parsing #{user.email}"
	try require('../server/parser') user, null, cb, succinct_manual
	catch err
		console.log "error in nudge parse for #{user.email}"
		console.dir err
		cb()

eachDoc = (docs, operate, fcb) ->
	if not docs.length then return fcb()
	doc = docs.pop()
	operate doc, ()-> eachDoc docs, operate, fcb


require('../server/models').User.find (err, users) ->
	throw err if err
	eachDoc users.slice(), eachLink, ()->
		eachDoc users, eachParse, ()->
			require('phrenetic/lib/server/services').close()

