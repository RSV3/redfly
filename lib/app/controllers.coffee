module.exports = (Ember, App) ->
	# path = require 'path'
	# views = path.dirname(path.dirname(__dirname)) + '/views/templates'
	# views = '../../views/templates'


	App.ApplicationView = Ember.View.extend
		templateName: 'application'
		# template: require '../../views/templates/application'
		didInsertElement: ->
			# TODO maybe do this without css selector if possible
			$('.search-query').addClear top: 6
	App.ApplicationController = Ember.Controller.extend() #recentContacts: App.Contacts.find() @where('added_date').exists(1).sort(['date', 'desc']).limit(3)


	App.HomeView = Ember.View.extend
		templateName: 'home'
		# template: require '../../views/templates/home'
		toggle: ->
			@get('controller').set 'showConnect', true
	App.HomeController = Ember.Controller.extend
		showConnect: false

	App.ContactView = Ember.View.extend
		templateName: 'contact'
		# template: require '../../views/templates/contact'
	App.ContactController = Ember.ObjectController.extend
		firstName: (->
				name = @get('name')
				name[...name.indexOf(' ')]
			).property('name')

	App.ProfileView = Ember.View.extend
		templateName: 'profile'
		# template: require '../../views/templates/profile'
	App.ProfileController = Ember.ObjectController.extend
		contacts: (-> App.Contact.find addedBy: @._id)
			.property()
		total: (-> @get('contacts').get 'length')	# TODO not working
			.property('contacts')

	App.TagsView = Ember.View.extend
		templateName: 'tags'
		# template: require '../../views/templates/tags'
	App.TagsController = Ember.ArrayController.extend()

	App.ReportView = Ember.View.extend
		templateName: 'report'
		# template: require '../../views/templates/report'
	App.ReportController = Ember.Controller.extend()
	