# TODO XXX


get '/classify/:step?', (page, model, {step}) ->
	step or= 1
	step = 0 + step
	userModel = model.at('_user')
	user = userModel.get()
	userModel.set 'classifyIndex', step

	total = user.classify.length
	if step > total
		page.redirect '/'

	model.subscribe model.query('contacts').findById(user.classify[step - 1]), (err, contact) ->
		throw err if err

		context =
			step: step
			nextStep: step + 1
			total: total
		common page, model, user, contact, context


ready (model) ->
	user = model.at '_user'
	contact = model.at '_contact'
	notes = contact.at 'notes'

	@next = (event, element, next) ->
		contact.set 'date_added', +new Date
		contact.set 'added_by', user.get().id
		# TODO XXX prolly won't work for making the link trigger. If it does, try without!
		next()
