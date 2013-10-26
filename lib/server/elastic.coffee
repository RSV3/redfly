
ElasticSearchClient = require 'elasticsearchclient'
_ = require 'underscore'

myESclient = null
myESindex = null


ES_client = ->
	if not myESclient
		server = process.env.ES_URL
		bits = server.split '@'
		auth = bits[0].split ':'
		serverOptions =
			host: bits[1]
			auth:
				username: auth[1].substring(2)
				password: auth[2]
		myESclient = new ElasticSearchClient serverOptions
	myESclient


ES_index = ->
	if not myESindex then myESindex = process.env.ES_NAME or 'redfly'
	myESindex


# save records
ES_create = (rec, cb)->
	ES_client()?.index ES_index(), 'contact', rec, String(rec._id), (err, data)->
		if err
			console.log "ES ERR: creating data"
			console.dir err
			console.dir data
		cb? err


# return all records!
ES_scan = (cb) ->
	ES_client()?.scan ES_index(), 'contact', (err, data)->
		if err
			console.log "error scanning #{name} on ES"
			console.dir query
			console.dir err
			data = null
		if data then data = JSON.parse(data)
		cb? err, data?._scroll_id

# scroll teams with scan
ES_scroll = (id, cb) ->
	ES_client()?.scroll id, (err, data)->
		if err
			console.log "error scrolling #{id} on ES"
			console.dir query
			console.dir err
			data = null
		if data then data = JSON.parse(data)
		cb? err, data


# this function searches the contact index on elastic search
# it takes a list of fields: ['tags', 'names', 'company']
# a terms string: 'fred smith'
# an array of filter objects: {or:[{terms:{tags.body.full:'media'}}, ...]}, ...
# a sort object
# and options: flags for facets and highlights, and skip/limit counts
ES_search = (fields, terms, filters, sort, options, cb)->

	tagfields = []
	for field in fields
		if field
			if field is 'tag'
				tagfields.push 'indtags.body'
				tagfields.push 'orgtags.body'
			else if field is 'note' then tagfields.push 'notes.body'
			else if field is 'company' then tagfields.push field
			else tagfields.push "#{field}s"
	newq =
		query:filtered: filter:and:[exists:field:'added']
		from: options.skip
		size: options.limit
		fields: []
	if tagfields.length then newq.query.filtered.query = bool:should:multi_match:{query:terms, fields:[]}

	if options.highlights then newq.highlight = fields:{}
	for field in tagfields
		newq.query.filtered.query.bool.should.multi_match.fields.push "#{field}.full"
		newq.query.filtered.query.bool.should.multi_match.fields.push "#{field}.autocomplete"
		if field.indexOf('tags.body') > 0
			newq.query.filtered.query.bool.should.multi_match.fields.push "#{field}.raw"
		if options.highlights then newq.highlight.fields["#{field}.autocomplete"] = {}

	for filt in filters
		newq.query.filtered.filter.and.push filt

	if options.facets then newq.facets =
		knows:terms:{size:7, field:'knows'}
		indtags:terms:{size:7, field:'indtags.body.raw'}
		orgtags:terms:{size:7, field:'orgtags.body.raw'}

	if sort and _.keys(sort).length then newq.sort = sort

	ES_client()?.search ES_index(), 'contact', newq, (err, data)->
		if err
			console.log "error querying #{name} on ES"
			console.dir query
			console.dir err
			data = null
		else if options.facets
			facets = JSON.parse(data)?.facets
			if facets
				tmpfacets ={}
				for f in _.keys(facets)
					tmpfacets[f] = _.pluck facets[f].terms, 'term'
				facets = tmpfacets
		if data then data = JSON.parse(data)?.hits
		if not data?.hits
			console.log "ERROR:"
			console.dir data
			console.log require('util').inspect newq, depth:null
			dox = null
		else dox = _.map data.hits, (i)->
			hit = _id:i._id
			if i.highlight
				hit.field = _.keys(i.highlight)?[0] or ''
				hit.fragment = i.highlight[hit.field][0] or ''
				hit.field = hit.field.split('.')?[0] or ''
			hit
		cb? err, data?.total, dox, facets


ES_update = (id, update, cb)->
	ES_client()?.update ES_index(), 'contact', id, update, null, (err, data)->
		if err
			console.log "error updating #{id} on ES"
			console.dir err
		cb? err


ES_delete = (id, cb)->
	ES_client()?.deleteDocument ES_index(), 'contact', id, null, (err)->
		if err
			console.log "error deleting #{id} on ES"
			console.dir err
		cb? err


# this little routine updates the relevant elasticsearch document when we add or remove tags or notes
runScriptOnOp = (doc, type, field, script, cb)->
	user = doc.creator or doc.author
	if not doc.contact or not user then return
	esup_doc =
		params: val: {user:String(user), body:doc.body}
		script: script
	ES_update String(doc.contact), esup_doc, (err)->
		if err
			console.log "ERR: ES adding new #{field} #{doc.body} to #{doc.contact} from #{user}"
			console.dir doc
			console.dir err
		return cb? err

# for a given doc of type 'type', add the corresponding object to field on the ES index
# (used for tags and notes)
ES_updateOnCreate = (doc, type, field, cb)->
	runScriptOnOp doc, type, field, """
		if (ctx._source.?#{field} == empty) {
			ctx._source.#{field}=[val]
		} else if (ctx._source.#{field}.contains(val)) {
			ctx.op = "none"
		} else {
			ctx._source.#{field} += val
		} """, cb

# for a given doc of type 'type', remove the corresponding object from field on the ES index
# (useful for tags and notes)
ES_updateOnDelete = (doc, type, field, cb)->
	runScriptOnOp doc, type, field, """
		if (ctx._source.?#{field} == empty) {
			ctx.op="none"
		} else if (ctx._source.#{field} == val) {
			ctx._source.#{field} = null
		} else if (ctx._source.#{field}.contains(val)) {
			ctx._source.#{field}.remove(val)
		} else {
			ctx.op = "none"
		} """, cb


ES_get = (id, cb)->
	ES_client()?.get ES_index(), 'contact', id, (err, data)->
		if err
			console.log "ES ERR: getting #{id}"
			console.dir err
			console.dir data
		cb? err, data


module.exports =
	client: ES_client
	create: ES_create
	delete: ES_delete
	update: ES_update
	find: ES_search
	get: ES_get
	scan: ES_scan
	scroll: ES_scroll
	onCreate: ES_updateOnCreate
	onDelete: ES_updateOnDelete

