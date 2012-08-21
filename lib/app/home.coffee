{get, ready, view} = require './index'


get '/', (page, model) ->
	page.render 'home'


ready (model) ->
	@toggle = ->
		model.set '_showConnect', true
