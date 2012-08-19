_ = require 'underscore'

# Called on both the server and browser before rendering.
# exports.init = (model) ->

# Called after the component is created and has been added to the DOM. Only runs in the browser.
exports.create = (model, dom) ->
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

	contact = model.at('contact')
	# Workaround, macros don't seem to work
	model.ref '_contact', contact

	model.fn '_availableTags', 'contacts', (contacts) ->
		return ['asdfadfasdf', 'qwer']
	
	model.on 'set', '_currentTag', ->
		field = $('.new-tag')
		field.attr 'size', 1 + field.val().length

	$ ->
		$('.tagger').click ->
			$(this).find('.new-tag').focus()	

	@add = (event, element) ->
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
