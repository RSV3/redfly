module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'



	App.ApplicationView = Ember.View.extend
		template: require '../../../templates/application'

		didInsertElement: ->

			# Update contacts if they recieve additional linkedin data.
			socket.on 'linked', (changes) =>
				changes = _.filter changes, (change) ->
					App.store.recordIsLoaded App.Contact, change
				if not _.isEmpty changes
					App.Contact.find _id: $in: changes

			# TO-DO Maybe create a pattern for the simple use case of using a socket to get and set one value.
			socket.emit 'summary.organisation', (title) ->
				App.set 'orgTitle', title
			socket.emit 'summary.contacts', (count) =>
				@set 'controller.contactsQueued', count
			socket.emit 'summary.tags', (count) =>
				@set 'controller.tagsCreated', count
			socket.emit 'summary.notes', (count) =>
				@set 'controller.notesAuthored', count
			socket.emit 'summary.verbose', (verbose) =>
				@set 'controller.mostVerboseTag', verbose
			socket.emit 'summary.user', (user) =>
				@set 'controller.mostActiveUser', user

		spotlightSearchView: App.SearchView.extend
			tagName: 'li'
			select: (context) ->
				@get('controller.target').transitionToRoute 'contact', context
