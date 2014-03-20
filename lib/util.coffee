_ = require 'underscore'
_s = require 'underscore.string'
util = _.extend module.exports, require('../phrenetic/lib/util.coffee')


util.nickname = (name, email) ->
	if name
		if _s.contains name, ' '
			return name[...name.indexOf(' ')]
		return name
	if email
		return _.first email.split('@')

util.socialPatterns =
	linkedin: /^[\w\/\-\.]*$/
	twitter: /^[\w\-\.]*$/
	facebook: /^[\w\-\.]*$/
	linkedinugly: /^[\w\/\-\.]*$/
	linkedinprivate: /^[0-9]*$/
	linkedincustom: /^[\w]*$/
