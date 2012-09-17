module.exports = (Ember, App) ->
	_ = require 'underscore'
	_s = require 'underscore.string'

	# path = require 'path'
	# views = path.dirname(path.dirname(__dirname)) + '/views/templates'
	# views = '../../views/templates'


	App.ApplicationView = Ember.View.extend
		templateName: 'application'
		# template: require '../../views/templates/application'
		didInsertElement: ->
			# TODO maybe do this without css selector if possible
			@$('.search-query').addClear top: 6
	App.ApplicationController = Ember.Controller.extend() #recentContacts: App.Contacts.find() @where('added_date').exists(1).sort(['date', 'desc']).limit(3)


	App.HomeView = Ember.View.extend
		templateName: 'home'
		classNames: ['home']
		# template: require '../../views/templates/home'
		toggle: ->
			@get('controller').set 'showConnect', true
	App.HomeController = Ember.Controller.extend()

	App.ContactView = Ember.View.extend
		templateName: 'contact'
		classNames: ['contact']
		# template: require '../../views/templates/contact'
	App.ContactController = Ember.ObjectController.extend
		firstName: (->
				name = @get('name')
				name[...name.indexOf(' ')]
			).property 'name'

	App.ProfileView = Ember.View.extend
		templateName: 'profile'
		classNames: ['profile']
		# template: require '../../views/templates/profile'
	App.ProfileController = Ember.ObjectController.extend
		contacts: (-> App.Contact.find addedBy: @._id)	# TODO XXX why is this a computed property, it doesn't change in response to anything on cont.
			.property()
		total: (-> @get('contacts').get 'length')	# TODO not working
			.property 'contacts' 

	App.TagsView = Ember.View.extend
		templateName: 'tags'
		classNames: ['tags']
		# template: require '../../views/templates/tags'
	App.TagsController = Ember.ArrayController.extend()

	App.ReportView = Ember.View.extend
		templateName: 'report'
		classNames: ['report']
		# template: require '../../views/templates/report'
	App.ReportController = Ember.Controller.extend()


	# TODO
	# - make sure clicking anywhere gives the new tag thing focus
	# - make sure all attrs on newTagView are rendered
	# - does currentTag need to be an ember object to get updated? Prolly not.
	App.TaggerView = Ember.View.extend
		templateName: 'tagger'
		classNames: ['tagger']
		click: (event) ->
			@$().focus()	# TODO this is wrong, get newTagView and focus on it
		add: (event) ->
			if tag = _s.trim @newTagView.get('currentTag')
				existingTag = _.find @get('controller'), (otherTag) ->	# TODO controller.content?
					tag is otherTag
				if not existingTag
					newTag = App.store.createRecord App.Tag,
						creator: App.user	# TODO this probably won't work, try .get 'content'
						body: tag
					App.store.commit()
					@get('controller').pushObject newTag
					# TODO find the element of the tag and: $().addClass 'animated bounceIn'
				else
					# TODO find the element of the tag and play the appropriate animation
					# probably make it play faster, like a mac system componenet bounce
					# existingTag.$().addClass 'animated pulse'
				@newTagView.set 'currentTag', null
		tagView: Ember.View.extend
			tagName: 'span'
			remove: ->
				tag = @get 'content'
				@parentView.get('controller').removeObject tag
				$().addClass 'animated rotateOutDownLeft'
		newTagView: Ember.TextField.extend
			attributeBindings: ['data-source']
			data-source: @get('controller').get 'availableTags'
			change: (event) ->
				event.target.attr 'size', 1 + @currentTag.length	# TODO is input size changing when typeahead preselect gets entered
	App.TaggerController = Ember.ArrayController.extend
		availableTags: ['An example tag', 'Yet another example tag!']	# TODO
		availableTags: (->
				allTags = App.Tag.find()	# TODO XXX distinct tags
				_.reject allTags, (otherTag) ->
					for tag in @get('content')
						tag.body is otherTag.body
			).property 'content'


