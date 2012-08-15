# Called on both the server and browser before rendering.
exports.init = (model) ->
	# TODO XXX
	model.fn '_availableTags', 'contacts', (contacts) ->
		return ['asdfadfasdf', 'qwer']

# Called after the component is created and has been added to the DOM. Only runs in the browser.
exports.create = (model, dom) ->
	model.on 'set', '_currentTag', ->
		field = $('.new-tag')
		field.attr 'size', 1 + field.val().length

	$ ->
		$('.tagger').click ->
			$(this).find('.new-tag').focus()


exports.add = (event, element) ->
	# contact = model.at 'contacts.178'

	# currentTag = model.at '_currentTag'
	# tag = currentTag.get()?.trim()
	# if tag
	# 	tags = contact.at 'tags'
	# 	if not _.contains tags.get(), tag
	# 		tags.push tag
	# 	currentTag.set ''

exports.remove = (event, element) ->
	tag = model.at element
	# tags = model.parent tag
	# model.remove tags.path(), tag.leaf()
	# TODO hack
	path = tag.path().substring(0, tag.path().lastIndexOf('.'))
	model.remove path, tag.leaf()
