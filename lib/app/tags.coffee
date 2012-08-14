{get, ready, view} = require './index'


get '/tags', (page, model) ->
	page.render 'tags'


ready (model) ->
	$ ->
