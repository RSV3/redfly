_ = require 'underscore'
derby = require 'derby'

{get, view, ready} = derby.createApp module

derby.use(require '../../ui')


get '*', (page, model, params, next) ->
	model.subscribe 'contacts.178', (err, contact) ->
		model.ref '_contact', contact

		model.fn '_availableTags', 'contacts', 'contacts.178.tags', (contacts, tags) ->
			# Model.fn must be pure function so I can't use underscore to do this, and even coffeescipt lexical scoping sometimes causes errors.
			availableTags = []
			for id, contact of contacts
				if contact.tags
					for tag in contact.tags
						unless availableTags.indexOf(tag) isnt -1 or tags.indexOf(tag) isnt -1
							availableTags.push tag
			return availableTags

	next()


ready (model) ->
	contact = model.at 'contacts.178'

	model.on 'set', '_currentTag', ->
		field = $('.new-tag')
		field.attr 'size', 1 + field.val().length

	@add = ->
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

	$ ->
		$('.tagger').click ->
			$(this).find('.new-tag').focus()


require './home'