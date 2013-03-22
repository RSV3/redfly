_ = require 'underscore'
util = require './util'
models = require './models'


_addTags = (user, contact, category, existing, alist) ->
	if not alist.length then return
	tag = alist.shift()
	if not tag then return
	tag = util.trim tag.toLowerCase()
	if not _.select(existing, (t) -> t is tag).length
		newt = new models.Tag
			creator: user
			contact: contact
			category: category
			body: tag
		newt.save (err) ->
			_addTags user, contact, category, existing, alist
	else
		_addTags user, contact, category, existing, alist


module.exports = (user, contact, category, alist) ->
	if not alist.length then return
	models.Tag.find {category: category, creator: user._id, contact: contact._id}, (err, existing) ->
		_addTags user, contact, category, _.pluck(existing, 'body'), alist

