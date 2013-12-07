# refactored search:
# optional limit for the dynamic searchbox,
# and a final callback where we can decide what attributes to package for returning
_ = require 'underscore'
Models = require './models'
Elastic = require './elastic'

module.exports = (fn, data, session, limit=0) ->

	searchPagePageSize = 10		# used internally for paging

	query = data.filter or data.query or ''
	compound = _.compact query.split ':'
	if not compound.length then terms=''
	else terms = compound[compound.length-1]

	if not limit and (query.length or data.moreConditions)
		Models.Admin.update {_id:1}, $inc: 'searchCnt': 1, (err)->
			if err then console.dir err

	availableTypes = ['name', 'email', 'company', 'tag', 'note']
	fields = []		# this array maps the array of results to their type
	if compound.length is 1						# type specified, eg tag:slacker
		for type in availableTypes
			fields.push type
	else if compound[0] is 'contact'
		fields = ['name', 'email']
	else fields = [compound[0]]

	filters = []
	if data.moreConditions?.addedBy then filters.push terms:addedBy:[data.moreConditions.addedBy]
	if data.moreConditions?.poor
		filters.push terms:addedBy:[session.user]
		filters.push missing:field:"indtags"
		filters.push missing:field:"orgtags"
	if data.knows?.length then filters.push terms:knows:data.knows
	if data.industry?.length 
		thisf = []
		for tag in data.industry
			thisf.push term:"indtags.body.raw":tag,
		if data.indAND then filters.push "and":thisf
		else filters.push "or":thisf
	if data.organisation?.length 
		thisf = []
		for tag in data.organisation
			thisf.push term:"orgtags.body.raw":tag
		if data.orgAND then filters.push "and":thisf
		else filters.push "or":thisf

	sort = {}
	if data.sort
		key = data.sort
		if key[0] is '-'
			key=key.substr 1
			dir = 'desc'
		else dir = 'asc'
		if key is "names"
			key = "sortname"
			sort[key]=dir
			delete data.sort
		else if key is 'added'
			sort[key]=dir
			delete data.sort
		else
			key="#{key}.value"
			sort[key]=dir
	else if not query.length
		sort.added = 'desc'
		filters.push exists:field:"classified"

	if not limit
		options = {limit:searchPagePageSize, facets: not data.filter and not data.moreConditions?.poor, highlights: false}
		if data.page then options.skip = data.page*searchPagePageSize
	else options = {limit:limit, skip:0, facets: false, highlights: true}
	Elastic.find fields, terms, filters, sort, options, (err, totes, docs, facets) ->
		throw err if err
		resultsObj = query:query
		if docs?.length
			if facets then resultsObj.facets = facets
			if docs[0].field
				resultsObj.response = {}
				for d in docs
					if String(d._id) isnt data.moreConditions?._id?.$ne
						if _.contains ['indtags','orgtags'], d.field then thefield = 'tags'
						else thefield = d.field
						if not resultsObj[thefield] then resultsObj[thefield] = []
						resultsObj[thefield].push {_id:d._id, fragment:d.fragment}
			else
				resultsObj.response = _.pluck docs, '_id'
				resultsObj.totalCount = resultsObj.filteredCount = totes
		return fn resultsObj
