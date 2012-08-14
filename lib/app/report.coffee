{get, ready, view} = require './index'


get '/report', (page, model) ->
	page.render 'report'


ready (model) ->
	$ ->
