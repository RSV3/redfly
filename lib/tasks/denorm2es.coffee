
moment = require 'moment'
_ = require 'underscore'
_s = require 'underscore.string'

services = require 'phrenetic/lib/server/services'
ElasticSearchClient = require 'elasticsearchclient'


models = require '../server/models'

globalcount = 0


_populate = (c, name, rex, done)->
	if not rex?.length then return done()
	if rec = rex.pop()
		if name is 'tags'
			newrec = {body:rec.body, user:rec.creator}
			if rec.category is 'industry' then thisname = 'indtags'
			else thisname = 'orgtags'
		else if name is 'measurements'
			thisname = rec.attribute
			if not (old = c._doc[thisname]) then newrec = {count:1, value:rec.value}
			else newrec = {count:old.count+1, value:(rec.value+old.value*old.count)/(old.count+1)}
		else if name is 'notes'
			thisname = name
			newrec = {body:rec.body, user:rec.author}
		else return console.log "ERROR: unexpected attribute name #{name}"
		if not c._doc[thisname] then c._doc[thisname] = []
		c._doc[thisname].push newrec
	_populate c, name, rex, done

populate = (c, name, done)->
	models[_s.capitalize name].find {contact:c._id}, (err, rex) ->
		throw err if err
		_populate c, "#{name}s", rex, done

# save contacts
eachSave = (c, name, done)->
	populate c, 'tag', ->
		populate c, 'measurement', ->
			populate c, 'note', ->
				elasticSearchClient.index('redstar', name, c, String(c._id)
				).on('data', (data)->
					globalcount++
					done()
				).exec()

# recursively operate on a list of documents
eachDoc = (docs, operate, name, fcb) ->
	if not docs.length then return fcb()
	doc = docs.pop()
	operate doc, name, ->
		console.log "#{name} #{globalcount} #{doc.names[0]}"
		eachDoc docs, operate, name, fcb

saveAll = (name, alldone)->
	globalcount = 0
	limit = {}
	#globalcount = limit.skip = 539
	models[_s.capitalize name].find {added:$exists:true}, {}, limit, (err, recs) ->
		throw err if err
		console.dir "got #{recs.length} #{name}s"
		eachDoc recs, eachSave, name, alldone

# work begins here:
console.log "starting migrateES with flag: #{process.argv[3]}"


bonsai = process.env.BONSAI_URL
bits = bonsai.split '@'
auth = bits[0].split ':'

serverOptions =
	host: bits[1]
	auth:
		username: auth[1].substring(2)
		password: auth[2]

console.dir serverOptions
elasticSearchClient = new ElasticSearchClient serverOptions

saveAll 'contact', ->
	console.log "calling services close"
	services.close()
	return console.log "called services close"

