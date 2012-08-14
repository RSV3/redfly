{get, ready, view} = require './index'


get '/contact/:id', (page, model, {id}) ->

	model.subscribe 'contacts.' + id, (err, contact) ->
		throw err if err		
		model.ref '_contact', contact

		

		page.render 'contact'


ready (model) ->
	$ ->
