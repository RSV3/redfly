{get, ready, view} = require './index'


get '/', (page, model) ->
	page.render 'home'


ready (model) ->
	$ ->
		$('#connectButton').click ->
			$('#connectButton, #connectForm').toggle()