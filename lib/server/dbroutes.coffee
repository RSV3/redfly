_ = require 'underscore'
_s = require 'underscore.string'
marked = require 'marked'
cheerio = require 'cheerio'
Models = require './models'
Elastic = require './elastic'
Linker = require './linker'
linkLater = require('./linklater')
addDeets2Contact = linkLater.addDeets2Contact
# ScrapeLI = require './linkscraper'


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

routes =  (app, data, io, session, fn)->

	cb = (payload) ->
		if not fn then return
		root = _s.underscored data.type
		if _.isArray payload then root += 's'
		hash = {}
		hash[root] = payload
		fn hash

	model = Models[data.type]

	# add details about doc into feed
	feed = (doc, type) ->
		o = {type: type, id: doc.id}
		if doc.addedBy then o.addedBy = doc.addedBy
		if doc.response?.length then o.response = doc.response
		if fn then io.broadcast 'feed', o
		else io.emit 'linkscrapedtag', o


	switch data.op
		when 'find'
			# TODO
			try
				if id = data.id
					model.findById id, (err, doc) ->
						throw err if err
						if data.type is 'Admin'
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
				else if ids = data.ids
					if not ids.length then return cb []
					model.find _id: $in: ids, (err, docs) ->
						throw err if err
						docs = _.sortBy docs, (doc) ->
							ids.indexOf doc.id
						cb docs
				else
					schemas = require '../schemas'
					if schemas[data.type].base
						data.query ?= conditions: {}
						data.query.conditions._type = data.type
					if query = data.query
						if not query.conditions and not query.options
							query = conditions: query
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

		when 'create'
			record = data.record
			if _.isArray record then throw new Error 'unimplemented'
			switch model
				when Models.Contact
					if record.names?.length and not record.sortname then record.sortname = record.names[0].toLowerCase()
					if record.addedBy and not record.knows?.length then record.knows = [record.addedBy]
				when Models.Note
					record.body = marked record.body												# encode markdown, but
					if ($b = cheerio.load(record.body)('p'))?.length then record.body = $b.html()	# dont wrap in paragraphs
				when Models.LinkScraped
					# before creating a new LinkScraped record, see if it matches a known contact
					Linker.matchContact session.user, record.name.firstName, record.name.lastName, record.name.formattedName, (contact)->
						if contact				#	and if it does, then trye to add some details from the linkedin record to the contact
							Models.User.findById session.user, (err, user) ->
								throw err if err
								record.contact = addDeets2Contact null, user, contact, record
			model.create record, (err, doc) ->
				if err
					console.log "ERROR: creating record"
					console.dir err
					console.dir record
					throw err unless err.code is 11000		# duplicate key
					doc = record
				cb doc
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
							feed doc, data.type
					when Models.Contact
						if doc.addedBy
							feed doc, data.type
							Elastic.create doc, (err)->
								if err
									console.log "ERR: ES creating new contact"
									console.dir doc
									console.dir err
					when Models.Request
						feed doc, data.type

		when 'save'
			record = data.record
			if _.isArray record then throw new Error 'unimplemented'
			model.findById record.id, (err, doc) ->
				throw err if err
				if not doc
					console.log "ERROR: failed to find record to save:"
					console.dir data
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
								feed doc, data.type
								Models.Response.findById _.last(doc.response), (err, r)->
									if err or not r?.contact?.length then return
									console.dir r
									Models.User.findById doc.user, (err, u)->
										if err or not u then return
										console.dir u
										b = "recommended for #{u.name}'s request: _#{doc.text}_"
										for c in r.contact
											rec = {author:r.user, contact:c, body:b}
											console.dir rec
											routes app, {op:'create', type:'Note', record:rec}, io, session
						when Models.Contact
							if doc.added
								if 'added' in modified
									feed doc, data.type
									primeContactForES doc, (doc)->
										Elastic.create doc, (err)->
											if not err then return
											console.log "ERR: ES updating #{type}"
											console.dir doc
											console.dir err
								else
									Elastic.update String(doc._id), doc:doc, (err)->
										if not err then return
										console.log "ERR: ES updating #{type}"
										console.dir doc
										console.dir err
							else if 'knows' in modified		# taken ourselves out of knows list?
								if not doc.knows.length
									Elastic.delete doc._id, (err)->
										if not err then return
										console.log "ERR: ES removing #{type}"
										console.dir doc
								else
									Elastic.update String(doc._id), doc:doc, (err)->
										if not err then return
										console.log "ERR: ES updating #{type}"
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
							###
							if 'linkedin' in modified
								ScrapeLI.contact session.user, doc, (deets)->
									updates = {}
									if deets.positions?.length and deets.positions[0] and not doc.position?.length
										updates.position = deets.positions[0]
									if deets.companies?.length and deets.companies[0] and not doc.company?.length
										updates.company = deets.companies[0]
									if deets.pictureUrl?.length and not doc.picture?.length
										updates.picture = deets.pictureUrl
									if deets.name?.length and not _.contains doc.names, deets.name
										doc.names.push deets.name
									if _.keys(updates)?.length
										updates.id = doc._id
										io.emit 'linkscrapedcontact', updates
										routes app, {op:'save', type:'Contact', record:updates}, io, session
									for skill in deets.specialties
										((rec)->
											Models.Tag.find rec, (terr, tags)->
												if tags?.length then return
												rec.user = session.user
												rec.category = 'industry'
												routes app, {op:'create', type:'Tag', record:rec}, io, session
										) {contact:doc._id, body:skill}
							###

		when 'remove'
			if id = data.id
				model.findByIdAndRemove id, (err, doc) ->
					throw err if err
					if not doc then return cb()
					switch data.type
						when 'Contact'
							Elastic.delete id, (err)->
								if err
									console.log "ERR: ES deleting #{id} on db remove"
									console.dir err
								cb()
						when 'Note'
							Elastic.onDelete doc, 'Note', "notes", (err)-> cb()
						when 'Tag'
							Elastic.onDelete doc, 'Tag', (if doc.category is 'industry' then 'indtags' else 'orgtags'), cb
						else cb()

			else if ids = data.ids
				throw new Error 'unimplemented'	# Remove each one and call cb() when they're all done.
			else
				throw new Error 'no id on remove'
		else
			throw new Error 'un recognised db route'


module.exports =
	routes: routes
	primeContactForES: primeContactForES

