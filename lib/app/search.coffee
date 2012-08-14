{get, ready, view} = require './index'


get '/search', (page, model) ->
	page.render 'search'


ready (model) ->
	$ ->
