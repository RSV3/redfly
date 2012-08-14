# Called on both the server and browser before rendering.
exports.init = (model) ->
	model.fn '_availableTags', 'contacts', 'contacts.178.tags', (contacts, tags) ->
		# Model.fn must be pure function so I can't use underscore to do this, and even coffeescipt lexical scoping sometimes causes errors.
		availableTags = []
		for id, contact of contacts
			if contact.tags
				for tag in contact.tags
					unless availableTags.indexOf(tag) isnt -1
						availableTags.push tag
		return availableTags

# Called after the component is created and has been added to the DOM. Only runs in the browser.
exports.create = (model, dom) ->
	model.on 'set', '_currentTag', ->
		field = $('.new-tag')
		field.attr 'size', 1 + field.val().length

	$ ->
		$('.tagger').click ->
			$(this).find('.new-tag').focus()


exports.add = ->
	contact = model.at 'contacts.178'

	currentTag = model.at '_currentTag'
	tag = currentTag.get()?.trim()
	if tag
		tags = contact.at 'tags'
		if not _.contains tags.get(), tag
			tags.push tag
		currentTag.set ''

exports.remove = (event, element) ->
	tag = model.at element
	# tags = model.parent tag
	# model.remove tags.path(), tag.leaf()
	# TODO hack
	path = tag.path().substring(0, tag.path().lastIndexOf('.'))
	model.remove path, tag.leaf()
