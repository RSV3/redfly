_ = require 'underscore'
derby = require 'derby'

{get, view, ready} = derby.createApp module

derby.use(require '../../ui')


get '*', (page, model, params, next) ->
	model.subscribe model.query('contacts').all(), (err, contacts) ->
		throw err if err
		model.ref '_recentContacts', contacts # TODO XXX contacts.sort('date')

		next()	# TODO XXX does this need to be scoped into 'subscribe'?

ready (model) ->


require './home'
require './contact'
require './search'
require './tags'
require './report'
