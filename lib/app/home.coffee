{get, ready, view} = require './index'


get '/', (page, model) ->
	page.render()


ready (model) ->
	$ ->
		$('#connectButton').click ->
			$('#connectButton, #connectForm').toggle()
