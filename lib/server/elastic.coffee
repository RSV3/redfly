
ElasticSearchClient = require 'elasticsearchclient'
_ = require 'underscore'

myESclient = null
myESindex = null


ES_client = ->
	if not myESclient
		bonsai = process.env.BONSAI_URL
		bits = bonsai.split '@'
		auth = bits[0].split ':'
		serverOptions =
			host: bits[1]
			auth:
				username: auth[1].substring(2)
				password: auth[2]
		myESclient = new ElasticSearchClient serverOptions
	myESclient


ES_index = ->
	if not myESindex then myESindex = process.env.ES_NAME or 'redstar'
	myESindex


# save records
ES_create = (rec, cb)->
	ES_client()?.index ES_index(), 'contact', rec, String(rec._id), (err, data)->
		console.log "ES create data"
		console.dir err
		console.dir data
		cb? err


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
		if options.facets
			facets = JSON.parse(data)?.facets
			if facets
				tmpfacets ={}
				for f in _.keys(facets)
					tmpfacets[f] = _.pluck facets[f].terms, 'term'
				facets = tmpfacets
		data = JSON.parse(data)?.hits
		dox = _.map data.hits, (i)->
			hit = _id:i._id
			if i.highlight
				hit.field = _.keys(i.highlight)?[0] or ''
				hit.fragment = i.highlight[hit.field][0] or ''
				hit.field = hit.field.split('.')?[0] or ''
			hit
		cb? err, data.total, dox, facets


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


module.exports =
	client: ES_client
	create: ES_create
	update: ES_update
	find: ES_search
	delete: ES_delete

