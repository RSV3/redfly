_ = require 'underscore'
util = require './util'
models = require './models'

Elastic = require './elastic'

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
			if not err and contact.added then Elastic.onCreate newt, 'Tag', (if category is 'industry' then 'indtags' else 'orgtags'), (err)->
				_addTags user, contact, category, existing, alist
	else
		_addTags user, contact, category, existing, alist


# the force flag tells us not to bother testing whether tags exist.
doAddTags = (user, contact, category, alist, force=false) ->
	if not alist.length then return

	###
	# ref #453
	# "Don't update industry tags if already been imported once
	# since it populates with junk tags again after clean up."
	# if we're not forcing, recall with force IFF there are no existing tags for this contact
	###
	if not force then return models.Tag.find {contact: contact._id}, (err, existing) ->
		if not existing?.length then doAddTags user, contact, category, alist, true

	# get any existing tag bodies, to avoid doubling up
	models.Tag.find {category: category, contact: contact._id}, (err, existing) ->
		_addTags user, contact, category, _.pluck(existing, 'body'), alist

module.exports = doAddTags

