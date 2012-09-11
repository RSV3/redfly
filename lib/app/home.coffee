{get, ready, view} = require './index'


get '/', (page, model) ->
	page.render 'home'

	# Testing juunk

	# id = model.id()
	# history =
	# 	id : id
	# 	date: +new Date
	# 	user: 56
	# 	contact: 45
	# 	count: 1
	# model.set 'history.' + id, history

	# model.subscribe model.query('history').forConnection(56, 45), (err, history) ->
	# 	throw err if err
	# 	console.log 'asdf'
	# 	console.log history.get()


