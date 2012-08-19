_ = require 'underscore'
derby = require 'derby'

{get, view, ready} = derby.createApp module

derby.use(require '../../ui')


get '*', (page, model, params, next) ->
	model.subscribe 'contacts', (err, contacts) ->
		throw err if err
		model.ref '_recentContacts', model.sort('contacts', 'date')

		next()	# TODO XXX does this need to be scoped into 'subscribe'?

require './home'
require './contact'
require './search'
require './tags'
require './report'
