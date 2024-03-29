module.exports = (Ember, App) ->
	_ = require 'underscore'
	_s = require 'underscore.string'
	socketemit = require '../socketemit.coffee'


	App.ApplicationView = Ember.View.extend
		template: require '../../../templates/application.jade'
		loggingOn: false

		showLogin: false
		advanced: false
		noPassword: ->
			@set 'showLogin', false
		getPassword: ->
			@set 'showLogin', true

		store: null
		didInsertElement: ->

			store = @store = @get('controller').store
			App.admin?.set 'extensionOn', $('.redfly-flag-extension-is-loaded').length

			# Update contacts if they recieve additional linkedin data.
			###
			# SOCKET IO LOSS: we can't do this easily without socket.io
			#socket.on 'linked', (changes) =>
				changes = _.filter changes, (change) ->
					store.recordIsLoaded App.Contact, change
				if not _.isEmpty changes then store.find 'contact', changes
			###

			# TO-DO Maybe create a pattern for the simple use case of using a socket to get and set one value.
			socketemit.get 'summary.organisation', (title) ->
				App.set 'orgTitle', title
			socketemit.get 'summary.contacts', (count) =>
				@set 'controller.contactsQueued', count
			socketemit.get 'summary.tags', (count) =>
				@set 'controller.tagsCreated', count
			socketemit.get 'summary.notes', (count) =>
				@set 'controller.notesAuthored', count
			socketemit.get 'summary.verbose', (verbose) =>
				@set 'controller.mostVerboseTag', verbose
			socketemit.get 'summary.user', (user) =>
				@set 'controller.mostActiveUser', user

			# handle the event sent by the browser plugin on installation
			Ember.$(document).on 'installExtension', null, (ev, tr)->
				App.admin.set 'extensionOn', true

			# handle the event sent by the browser plugin on scrape
			Ember.$(document).on 'saveExtension', null, (ev, tr)->
				if (ev = ev?.originalEvent?.detail).publicProfileUrl
					App.ls = Ember.ObjectProxy.create()
					lsinit = ->
						App.set 'ls', store.createRecord 'linkScraped', {
							publicProfileUrl:ev.publicProfileUrl
							users:[], positions:[], companies:[], specialties:[]
						}
					lshandler = ->
						if not App.get('ls') or not App.ls.get('id') then lsinit()
						App.ls.get('users').addObject store.find 'user', App.user.get 'id'
						if not App.ls.get 'name'
							App.ls.set 'name', formattedName:ev.name
							if ev.name?.length
								App.ls.set 'name.firstName', ev.name.split(' ')[0]
								App.ls.set 'name.lastName', ev.name.split(' ')[1..].join(' ')
						if ev.positions
							for own i,val of ev.positions
								if not App.ls.get('positions').contains(ev.positions[i]) or not App.ls.get('companies').contains(ev.companies[i])
									App.ls.get('positions').pushObject ev.positions[i]
									App.ls.get('companies').pushObject ev.companies[i]
						if ev.specialties
							for spec in ev.specialties
								App.ls.get('specialties').addObject spec
						if not App.ls.get('pictureUrl')?.length then App.ls.set 'pictureUrl', ev.pictureUrl
						App.ls.save()
					App.set 'ls', store.find 'linkScraped', publicProfileUrl:ev.publicProfileUrl
					if App.get('ls.isLoaded') then lshandler()
					else
						App.ls.one 'didLoad', ->
							App.set 'ls', App.ls.get 'firstObject'
							if not App.get('ls') then lshandler()
							else if App.get('ls.isLoaded') then lshandler()
							else
								App.ls.one 'didLoad', lshandler
								App.ls.one 'becameError', lshandler
						App.ls.one 'becameError', lshandler


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
					socketemit.post 'login.contextio', transmit, (r) =>
						if r.err
							@$().find(".#{r.err}").addClass 'error'
							@set 'working', false
						else if r.id
							App.set 'user', @get('parentView.parentView.controller').store.find 'user', r.id
							@set 'working', false
							@.set 'parentView.parentView.showLogin', false
							socketemit.get 'session', (session) ->
								if session.user is r.id
									controller.transitionToRoute 'recent'
								else
									console.log "ERROR: rong user #{session.user} != #{r.id}"
									App.auth.logout()
						else console.dir r

