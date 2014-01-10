_ = require 'underscore'
validators = require('validator').validators
util = _.extend module.exports, require('../util'), require('phrenetic/lib/app/util')
util.isLIURL = (u)->
	if not u then false
	else if not validators.isUrl then false
	else u.match new RegExp 'linkedin.com/'
