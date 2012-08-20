{get, ready, view} = require './index'


get '/contact/:id', (page, model, {id}) ->
	model.subscribe 'contacts.' + id, (err, contact) ->
		throw err if err
		model.ref '_contact', contact

		page.render 'contact'


ready (model) ->
	contact = model.at '_contact'
	notes = contact.at 'notes'

	@add = ->
		currentNote = model.at '_currentNote'
		note = currentNote.get()?.trim()
		if note
			notes.unshift
				text: note
				date: +new Date	# TODO XXX
				author: 178	# TODO XXX
			currentNote.set ''
