middleware = require('everyauth').middleware()

require('phrenetic/lib/server') [middleware], ->
	require './auth'
