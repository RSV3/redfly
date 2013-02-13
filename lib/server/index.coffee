auth = require './auth'

require('phrenetic/lib/server') [auth.middleware()]
