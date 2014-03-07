_ = require 'underscore'
_s = require 'underscore.string'
marked = require 'marked'
cheerio = require 'cheerio'
Models = require './models'
Elastic = require './elastic'
Linker = require './linker'
ScrapeLI = require './linkscraper'
linkLater = require './linklater'
addDeets2Contact = linkLater.addDeets2Contact


# when we first add a contact to ES:
# A recently added contact may already have notes and tags,
# so we should look for em and add em to the doc we send to ES
primeContactForES = (doc, cb)->
	Models.Note.find {contact:doc._id}, (nerr, notes)->
		Models.Tag.find {contact:doc._id}, (terr, tags)->
			if not nerr and notes?.length
				doc._doc.notes = _.map notes, (n)-> {body:n.body, user:n.author}
			if not terr and tags?.length
				doc._doc.indtags = _.map _.filter(tags, (t)->t.category is 'industry'), (t)-> {body:t.body, user:t.creator}
				doc._doc.orgtags = _.map _.reject(tags, (t)->t.category is 'industry'), (t)-> {body:t.body, user:t.creator}
			cb doc


setupRoutes = (type, fn, doneSet)->
	cb = (payload) ->
		if not fn then return
		root = _s.underscored type
		if _.isArray payload then root += 's'
		hash = {}
		hash[root] = payload
		fn hash
	model = Models[_s.capitalize type]
	doneSet cb, model


getRoutes = (params, body, session, fn)->

	setupRoutes params.type, fn, (cb, model)->
		if params.op is 'find'
			try
				if body.id
					id = JSON.parse body.id
					model.findById id, (err, doc) ->
						throw err if err
						if params.type is 'Admin'
							process.env.ORGANISATION_DOMAINS ?= process.env.ORGANISATION_DOMAIN
							process.env.AUTH_DOMAINS ?= process.env.AUTH_DOMAIN
							process.env.AUTH_DOMAINS ?= process.env.ORGANISATION_DOMAINS
							if doc
								# mongoose is cool, but we need do this to get around its protection
								doc._doc['plugin'] = process.env.PLUGIN_URL
								if process.env.CONTEXTIO_KEY then doc._doc['contextio'] = true
								if process.env.GOOGLE_API_ID then doc._doc['googleauth'] = true
								if not doc.orgtagcats then doc._doc['orgtagcats'] = process.env.ORG_TAG_CATEGORIES
							else
								new_adm =
									_id: 1
									orgtagcats: process.env.ORG_TAG_CATEGORIES
									domains: process.env.ORGANISATION_DOMAINS.split /[\s*,]/
									authdomains: process.env.AUTH_DOMAINS.split /[\s*,]/
									plugin: process.env.PLUGIN_URL
								return model.create new_adm, (err, doc) ->
									throw err if err
									if process.env.CONTEXTIO_KEY then doc._doc['contextio'] = true
									if process.env.GOOGLE_API_ID then doc._doc['googleauth'] = true
									cb doc
						cb doc
				else if body.ids
					ids = JSON.parse body.ids
					if not ids.length then return cb []
					model.find _id: $in: ids, (err, docs) ->
						throw err if err
						docs = _.sortBy docs, (doc) ->
							ids.indexOf doc.id
						cb docs
				else if body.query
					query = JSON.parse body.query
					schemas = require '../schemas'
					if schemas[params.type].base
						query ?= conditions: {}
						query.conditions._type = params.type
					if not query.conditions and not query.options
						query = conditions: query
					if params.type is 'Tag' then query.conditions.deleted = $exists:false
					model.find query.conditions, null, query.options, (err, docs) ->
						throw err if err
						cb docs
				else
					model.find (err, docs) ->
							throw err if err
							cb docs
			catch err
				console.error 'Error in db API: ' + err
				cb()
		else
			throw new Error 'un recognised db GET route'


postRoutes = (params, body, session, fn)->

	# define the helper which can add details about doc into 'feed'
	feed = (doc, type) ->
		o = {type: type, id: doc.id}
		if doc.addedBy then o.addedBy = doc.addedBy
		if doc.response?.length then o.response = doc.response
		if fn
			console.dir o
			###
			# lose this without socket.io
			# io.broadcast 'feed', o
			###
		else
			console.dir o
			###
			# lose this without socket.io
			# io.emit 'linkscrapedtag', o
			###

	setupRoutes params.type, fn, (cb, model)->
		switch params.op
			when 'create'
				record = JSON.parse body.record
				if _.isArray record then throw new Error 'unimplemented'
				beforeSave = (cb)->
					switch model
						when Models.Contact
							if record.names?.length and not record.sortname then record.sortname = record.names[0].toLowerCase()
							if record.addedBy and not record.knows?.length then record.knows = [record.addedBy]
						when Models.Note
							record.body = marked record.body												# encode markdown, but
							if ($b = cheerio.load(record.body)('p'))?.length then record.body = $b.html()	# dont wrap in paragraphs
						when Models.LinkScraped
							# before creating a new LinkScraped record, see if it matches a known contact
							return Linker.matchContact session.user, record.name.firstName, record.name.lastName, record.name.formattedName, (contact)->
								unless contact then return cb()		# no match? move along then ...
								# try to add some details from the linkedin record to the contact
								Models.User.findById session.user, (err, user) ->
									throw err if err
									record.contact = addDeets2Contact null, user, contact, record
									cb()
						when Models.Tag
							return model.find({contact:record.contact, body:record.body, deleted:true}).remove cb
					cb()	# for whenever we didn't return in the switch
				afterSave = (doc)->
					switch model
						when Models.Note
							Elastic.onCreate doc, 'Note', "notes", (err)->
								if err then console.dir err
						when Models.Tag
							Elastic.onCreate doc, 'Tag', (if doc.category is 'industry' then 'indtags' else 'orgtags'), (err)->
								unless err then Models.User.update {_id:session.user}, $inc: 'dataCount': 1, (err)->
									if err
										console.log "error incrementing data count for #{user}"
										console.dir err
								feed doc, params.type
						when Models.Contact
							maybeAnnounceContact = (doc)->
								if doc.addedBy
									feed doc, params.type
									Elastic.create doc, (err)->
										if err
											console.log "ERR: ES creating new contact"
											console.dir doc
											console.dir err
							ScrapeLI.matchScraped doc, (scraped)->
								unless scraped then return maybeAnnounceContact doc
								Models.User.findById session.user, (err, user) ->
									throw err if err
									addDeets2Contact null, user, doc, scraped
									maybeAnnounceContact doc
									feed {id:doc.id, addedBy:session.user, doc:doc}, params.type
						when Models.Request
							feed doc, params.type
				beforeSave ->
					model.create record, (err, doc) ->
						if err
							console.log "ERROR: creating record"
							console.dir err
							console.dir record
							throw err unless err.code is 11000		# duplicate key
							doc = record
						cb doc
						afterSave doc

			when 'save'
				record = JSON.parse body.record
				if _.isArray record then throw new Error 'unimplemented'
				model.findById record.id, (err, doc) ->
					throw err if err
					if not doc
						console.log "ERROR: failed to find record to save:"
						console.dir body
						return cb null
					_.extend doc, record
					modified = doc.modifiedPaths()
					switch model
						when Models.Contact
							if record.added is null
								doc.set 'added', undefined
								doc.set 'classified', undefined
						when Models.Request
							if 'response' in modified		# keeping track of new response for req/res mail task
								doc.set 'updated', new Date()

					# Important to do updates through the 'save' call so middleware and validators happen.
					doc.save (err) ->
						if err
							console.dir err
							return cb null
						cb doc
						switch model
							when Models.Request
								if 'response' in modified		# want to make sure new responses get updated on the page
									feed doc, params.type
									Models.Response.findById _.last(doc.response), (err, r)->
										if err or not r?.contact?.length then return
										Models.User.findById doc.user, (err, u)->
											if err or not u then return
											b = "recommended for #{u.name}'s request: _#{doc.text}_"
											for c in r.contact
												rec = {author:r.user, contact:c, body:b}
												postRoutes {op:'create', type:'Note', record:rec}, session, fn
							when Models.Contact
								if doc.added
									if 'added' in modified
										feed doc, params.type
										primeContactForES doc, (doc)->
											Elastic.create doc, (err)->
												if not err then return
												console.log "ERR: ES updating #{type}"
												console.dir doc
												console.dir err
									else
										Elastic.update String(doc._id), doc:doc, (err)->
											if not err then return
											console.log "ERR: ES updating #{params.type}"
											console.dir doc
											console.dir err
								else if 'knows' in modified		# taken ourselves out of knows list?
									if not doc.knows.length
										Elastic.delete doc._id, (err)->
											if not err then return
											console.log "ERR: ES removing #{params.type}"
											console.dir doc
									else
										Elastic.update String(doc._id), doc:doc, (err)->
											if not err then return
											console.log "ERR: ES updating #{params.type}"
											console.dir doc
											console.dir err
								if 'classified' in modified
									Models.User.update {_id:session.user}, $inc: {'contactCount':1, 'fullCount':1}, (err)->
										if err
											console.log "error incrementing data count for #{session.user}"
											console.dir err
								else if 'updated' in modified
									Models.User.update {_id:session.user}, $inc: 'dataCount': 1, (err)->
										if err
											console.log "error incrementing data count for #{session.user}"
											console.dir err

			when 'remove'
				if body.id 
					id = JSON.parse body.id
					if params.type is 'Tag'	# tags aren't really deleted: instead, we set the 'deleted' flag
						return model.findById id, (err, doc) ->		# look in store to mark deleted
							if err then console.dir err
							if err or not doc then return cb()			# bail out if we don't have a doc
							whichtags = (if doc.category is 'industry' then 'indtags' else 'orgtags')
							Elastic.onDelete doc, 'Tag', whichtags, ->	# remove from search index
								doc.set 'deleted', true					# and mark as deleted
								doc.save (err)->
									if err then console.dir err
									return cb()
					model.findByIdAndRemove id, (err, doc) ->		# but if it's not a tag, find&rm
						throw err if err
						if not doc then return cb()
						switch params.type
							when 'Contact'
								Elastic.delete id, (err)->
									if err
										console.log "ERR: ES deleting #{id} on db remove"
										console.dir err
									cb()
							when 'Note'
								Elastic.onDelete doc, 'Note', "notes", (err)-> cb()
							else cb()

				else if body.ids
					ids = JSON.parse body.ids
					throw new Error 'unimplemented'	# Remove each one and call cb() when they're all done.
				else
					throw new Error 'no id on remove'
			else
				throw new Error 'un recognised db POST route'


module.exports =
	getRoutes: getRoutes
	postRoutes: postRoutes
	primeContactForES: primeContactForES

