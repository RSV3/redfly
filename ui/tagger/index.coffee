x-as="new-tag"


- components
  - make focus() call in tagger not be tied to css selectors use, x-bind="click: focus"



- make sure clicking anywhere gives the new tag thing focus
- make sure all attrs on newTagView are rendered
- does currentTag need to be an ember object to get updated? Prolly not.



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
	