_ = require 'underscore'
derby = require 'derby'

{get, view, ready} = derby.createApp module

derby.use(require '../../ui')


get '*', (page, model, params, next) ->
	model.subscribe 'contacts', (err, contacts) ->
		throw err if err
		model.ref '_recentContacts', model.sort('contacts', 'date')

		next()	# TODO XXX does this need to be scoped into 'subscribe'?

ready (model) ->
	# TODO XXX I never tested this, comment it back in and remove the other _availableTags below
	# model.fn '_availableTags', 'contacts', 'contacts.178.tags', (contacts, tags) ->
	# 	# Model.fn must be pure function so I can't use underscore to do this, and even coffeescipt lexical scoping sometimes causes errors.
	# 	availableTags = []
	# 	for id, contact of contacts
	# 		if contact.tags
	# 			for tag in contact.tags
	# 				unless availableTags.indexOf(tag) isnt -1 or tags.indexOf(tag) isnt -1
	# 					availableTags.push tag
	# 	return availableTags

	model.fn '_availableTags', 'contacts', (contacts) ->
		return ['asdfadfasdf', 'qwer']
	
	model.on 'set', '_currentTag', ->
		field = $('.new-tag')
		field.attr 'size', 1 + field.val().length

	$ ->
		$('.tagger').click ->
			$(this).find('.new-tag').focus()

	@add = (event, element) ->
		contact = model.at 'contacts.178'

		currentTag = model.at '_currentTag'
		tag = currentTag.get()?.trim()
		if tag
			tags = contact.at 'tags'
			if not _.contains tags.get(), tag
				tags.push tag
			currentTag.set ''

	@remove = (event, element) ->
		tag = model.at element
		# tags = model.parent tag
		# model.remove tags.path(), tag.leaf()
		# TODO hack
		path = tag.path().substring(0, tag.path().lastIndexOf('.'))
		model.remove path, tag.leaf()

require './home'
require './contact'
require './search'
require './tags'
require './report'
