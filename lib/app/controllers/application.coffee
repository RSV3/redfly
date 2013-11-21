module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'


	App.ApplicationView = Ember.View.extend
		template: require '../../../templates/application'
		loggingOn: false

		showLogin: false
		advanced: false
		noPassword: ->
			@set 'showLogin', false
		getPassword: ->
			@set 'showLogin', true

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
				$('li.search.dropdown').blur()
				@get('controller').transitionToRoute 'contact', context

		loginView: Ember.View.extend
			editView: Ember.View.extend
				tagName: 'span'
				classNames: ['overlay', 'password-login']
				field: Ember.TextField
				check: Ember.Checkbox
				advance: ->
					@toggleProperty 'parentView.parentView.advanced'
				login: ->
					controller = @get('controller')
					@set 'working', true
					@$().find(".error").removeClass("error")
					transmit =
						email:@get('email.value')
						password:@get('password.value')
					socket.emit 'login.contextio', transmit, (r) =>
						if r.err
							@$().find(".#{r.err}").addClass 'error'
							@set 'working', false
						else if r.id
							App.set 'user', App.User.find r.id
							@set 'working', false
							@.set 'parentView.parentView.showLogin', false
							socket.emit 'session', (session) ->
								if session.user is r.id
									controller.transitionToRoute 'recent'
								else
									console.log "ERROR: rong user #{session.user} != #{r.id}"
									App.auth.logout()
						else console.dir r

