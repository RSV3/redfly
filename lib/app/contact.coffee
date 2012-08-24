_ = require 'underscore'
{get, ready, view} = require './index'


view.fn 'firstName', ({name}) ->
	name[...name.indexOf(' ')]

view.fn 'linebreaks', (text) ->
	text.replace /\n/g, '<br>'


get '/contact/:email', (page, model, {email}) ->
	model.subscribe model.query('contacts').findByEmail(email), (err, contact) ->
		throw err if err
		common page, model, contact

get '/classify/:step?', (page, model, {step}) ->
	step or= 1
	user = model.at('_user').get()
	model.subscribe model.query('contacts').knownTo(user.id), (err, contacts) ->
		contacts.filter {where: {added_by: {equals: null}}}	# TODO XXX might need where:
		total = contacts.get().length
		# contacts.filter {date: {gt: }}	# TODO make sure they're only from the last week
		contacts.sort(['knows.' + user.id + '.count', 'desc']).one()
		context =
			step: step
			total: total
		common page, model, contacts, context

common = (page, model, contact, context) ->
	model.ref '_contact', contact
	if id = model.at('_user').get()?.id
		model.ref '_knows', contact.at('knows.' + id)

	context ?= {}
	page.render 'contact', context


ready (model) ->
	user = model.at '_user'
	contact = model.at '_contact'
	notes = contact.at 'notes'

	@add = ->
		currentNote = model.at '_currentNote'
		if note = _.str.trim currentNote.get()
			notes.unshift
				text: note
				date: +new Date
				author: user.get().id
			currentNote.set ''

	@next = (event, element, next) ->
		contact.set 'date_added', +new Date
		contact.set 'added_by', user.get().id
		# TODO XXX prolly won't work for making the link trigger. If it does, try without!
		next()



# The 'id' parameter can be a document id or an email. Emails make more meaningful forward-facing links.
# else
# 	model.subscribe 'contacts.' + id, (err, contact) ->
# 		throw err if err
# if _.str.contains id, '@'
# 	email = id