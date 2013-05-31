moment = require 'moment'
_ = require 'underscore'

models = require './models'


oneWeekAgo = moment().subtract('days', 700).toDate()

summaryQuery = (model, field, cb) ->
	models[model].where(field).gt(oneWeekAgo).count cb

exports.summaryContacts = (cb) ->
	summaryQuery 'Contact', 'added', cb

exports.summaryTags = (cb) ->
	summaryQuery 'Tag', 'date', cb

exports.summaryNotes = (cb) ->
	summaryQuery 'Note', 'date', cb

exports.countConts = (cb)->
	models.Contact.find(added:{$exists:true}).count cb

exports.myConts = (u, cb)->
	models.Contact.find(addedBy:u).where('added').gt(oneWeekAgo).count cb

exports.recentConts = (cb)->
	models.Contact.find({added:{$exists:true},picture:{$exists:true}}).sort(added:-1).limit(4).execFind (err, contacts)->
		if err then return cb err, contacts
		rcs = []
		_.each contacts, (contact)->
			pos = ""
			if contact.position
				pos += "#{contact.position} "
			if contact.company
				pos += "at #{contact.company}"
			if not (name = _.first(contact.names))
				email = _.first(contact.emails)
				splitted = email.split '@'
				domain = _.first _.last(splitted).split('.')
				name = _.first(splitted) + ' [' + domain + ']'
			rcs.push
				name: name
				picture: contact.picture
				position: pos
				link: '/contact/'+contact._id
		cb null, rcs

exports.recentOrgs = (cb)->
	models.Contact.where('added').gt(oneWeekAgo).execFind (err, contacts)->
		if err then return cb err, contacts
		companies = []
		_.each contacts, (contact)->
			if contact.company then companies.push contact.company
		companies =  _.countBy(companies, (c)->c)
		comps = []
		for c of companies
			if not c.match(new RegExp(process.env.ORGANISATION_TITLE, 'i'))
				comps.push { company:c, count:companies[c] }
		return cb null, _.sortBy(comps, (c)-> -c.count)[0..3]

