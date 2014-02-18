_ = require 'underscore'
util = require './util'
models = require './models'

Elastic = require './elastic'


# synchronously shift thru a list of tag strings to create tags for the user/contact/category
_addTags = (user, contact, category, alist) ->
	if not alist.length then return
	if not tag = alist.shift() then return
	newt = new models.Tag
		creator: user
		contact: contact
		category: category
		body: tag
	newt.save (err) ->
		if err then console.dir "Error #{err} saving #{category} tag #{tag} on #{contact} for #{user}"
		unless not err and contact.added then _addTags user, contact, category, alist		# next!
		whichtags = (if category is 'industry' then 'indtags' else 'orgtags')
		Elastic.onCreate newt, 'Tag', whichtags, (err)->
			_addTags user, contact, category, alist		# next!


# the force flag tells us not to bother testing whether tags exist.
doAddTags = (user, contact, category, alist) ->
	unless alist.length then return

	# get any existing tag bodies, to avoid doubling up
	# note, since we dont specify deleted:$exists:false, this will also exclude 'deleted' tags
	models.Tag.find {category: category, contact: contact._id}, (err, existing) ->
		if not err and existing?.length
			existing = _.pluck existing, 'body'
			alist = _.map alist, (tag)-> util.trim tag.toLowerCase()
			alist = _.difference alist, existing
		_addTags user, contact, category, alist

module.exports = doAddTags

