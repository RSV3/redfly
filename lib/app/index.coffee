derby = require 'derby'

{get, view, ready} = derby.createApp module

derby.use(require '../../ui')


## ROUTES ##

get '/', (page, model) ->
	page.render()


## CONTROLLER FUNCTIONS ##

ready (model) ->
