_ = require 'underscore'
_s = require 'underscore.string'
validators = require('validator').validators
moment = require 'moment'
derby = require 'derby'

{get, view, ready} = derby.createApp module

derby.use(require '../../ui')


view.fn 'date', (date) ->
	moment(date).format('MMMM Do, YYYY')


get '*', (page, model, params, next) ->
	# model.subscribe model.query('contacts').feed(), (err, contacts) ->
	# 	throw err if err
	# 	model.ref '_recentContacts', contacts

		# TODO hack to get around sessions not working
		userId = model.session?.user
		try 
			# $ will only be available on the client, exception otherwise
			asdf = $
			userId = $.cookie 'user'
		catch err
		if userId
			model.subscribe 'users.' + userId, (err, user) ->
				throw err if err
				model.ref '_user', user

				next()
		else
			next()


ready (model) ->
	@connect = ->
		emailModel = model.at '_email'
		if email = _s.trim(emailModel.get()).toLowerCase()
			model.set '_connectStarted', true
			# If only the username was typed, make it a proper email.
			if not validators.isEmail email
				email += '@redstar.com'
			$.post '/login', email: email, (redirect) ->
				window.location.href = redirect or '/profile'



require './home'
require './profile'
require './contact'
require './search'
require './tags'
require './report'
