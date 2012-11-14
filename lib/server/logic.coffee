moment = require 'moment'

models = require './models'


oneWeekAgo = moment().subtract('days', 7).toDate()

summaryQuery = (model, field, cb) ->
	models[model].where(field).gt(oneWeekAgo).count (err, count) ->
		cb err, count

exports.summaryContacts = (cb) ->
	summaryQuery 'Contact', 'added', cb

exports.summaryTags = (cb) ->
	summaryQuery 'Tag', 'date', cb

exports.summaryNotes = (cb) ->
	summaryQuery 'Note', 'date', cb
