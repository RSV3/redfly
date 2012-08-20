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

	#TODO input size isn't changing when typeahead preselect gets entered

	contact = model.at 'contact'
	tags = contact.at 'tags'

	model.fn '_availableTags', 'contacts', (contacts) ->
		return ['asdfadfasdf', 'qwer']

	model.on 'set', '_currentTag', ->
		field = $(dom.element('new-tag'))
		field.attr 'size', 1 + field.val().length

	$ ->
		$('.tagger').click ->
			$(this).find('.new-tag').focus()	

	@add = (event, element) ->
		currentTag = model.at '_currentTag'
		tag = currentTag.get()?.trim()
		if tag
			if not _.contains tags.get(), tag
				tags.push tag
			currentTag.set ''

	@remove = (event, element) ->
		model.at(element).remove()
