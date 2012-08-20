_ = require 'underscore'
moment = require 'moment'
derby = require 'derby'

{get, view, ready} = derby.createApp module

derby.use(require '../../ui')


view.fn 'date', (date) ->
	moment(date).format('MMMM Do, YYYY')



get '*', (page, model, params, next) ->
	# TODO XXX
	# model.subscribe 'contacts', (err, contacts) ->
	# 	throw err if err
	# 	model.ref '_recentContacts', model.sort('contacts', 'date')
	model.subscribe 'contacts.178', (err, contact) ->
		throw err if err
		model.ref '_recentContact', contact


		model.fetch 'users.178', (err, user) ->	# TODO XXX only if signed in, also do this better
			throw err if err
			model.ref '_user', user

			next()	# TODO XXX does this need to be scoped?


require './home'
require './contact'
require './search'
require './tags'
require './report'
