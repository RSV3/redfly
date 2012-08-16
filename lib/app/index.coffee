_ = require 'underscore'
derby = require 'derby'

{get, view, ready} = derby.createApp module

derby.use(require '../../ui')


get '*', (page, model, params, next) ->
	model.subscribe model.query('contacts').all(), (err, contacts) ->
		throw err if err
		model.ref '_recentContacts', contacts # TODO XXX contacts.sort('date')

		next()	# TODO XXX does this need to be scoped into 'subscribe'?

ready (model) ->
	# TODO XXX
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
