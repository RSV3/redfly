module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'
	util = require './util'


	interceptedPath = null	# TO-DO this doesn't work any more. The paradigm is flawed: we have to save this to the session to survive auth flow.

	Ember.Router.reopen
		connectem: (outlet, data) ->
			@get('applicationController').connectOutlet outlet, data
			if outlet is 'results'
				@get('applicationController').connectOutlet 'sidebar', 'SearchFilter'
			else
				@get('applicationController').connectOutlet 'sidebar', 'feed'
		transitionTo: (path, context) ->
			_ = require 'underscore'

			authenticated = App.user.get 'content'
			state = _.last path.split('.')
			if not authenticated and state not in ['root', 'index', 'unauthorized', 'invalid']
				interceptedPath = path
				App.get('router').send 'doIntercept'
			else
				@_super path, context


	# Ember.Route.reopen
	# 	enter: (router) ->
	# 		@_super router
	# 		# Pageviews correspond to leaf nodes, however there's nothing preventing us from tracking all sorts different actions with this
	# 		# google analytics router hook.
	# 		if @get('isLeafRoute')
	# 			path = @absoluteRoute router
	# 			_gaq.push ['_trackPageview', path]


	App.Router = Ember.Router.extend
		location: 'history'
		enableLogging: process.env.NODE_ENV is 'development'

		root: Ember.Route.extend
			index: Ember.Route.extend
				route: '/'
				connectOutlets: (router) ->
					router.connectem 'home'

			profile: Ember.Route.extend
				route: '/profile/:user_id'
				connectOutlets: (router, user) ->
					router.connectem 'profile', user

			searching: Ember.Route.extend
				route: '/searching'
				enter: (manager) ->
					search = App.get 'router.applicationView.spotlightSearchViewInstance.searchBoxViewInstance'
					if search
						search.set 'searching', true
				redirectsTo: 'results'

			results: Ember.Route.extend
				route: '/results'
				connectOutlets: (router) ->
					search = App.get 'router.applicationView.spotlightSearchViewInstance.searchBoxViewInstance'
					if search
						if search.get 'searching'
							socket.emit 'fullsearch', query: search.get('value'), moreConditions: search.get('parentView.conditions'), (results) =>
								if results and results.length is 1
									router.route '/contact/'+ results[0]
								else if results and results.length
									router.connectem 'results'
									router.get('resultsController').set 'results', Ember.ArrayProxy.create 
										content: App.Contact.find(_id: $in: results)
								else
									search.set 'noresults', true
						else
							router.connectem 'results'

			contact: Ember.Route.extend
				# TODO bring back all email serialization, also:
				# http://stackoverflow.com/questions/12064765/initialization-with-serialize-deserialize-ember-js
				# route: '/contact/:identity'
				route: '/contact/:contact_id'
				connectOutlets: (router, contact) ->
					router.connectem 'contact', contact
				# TODO try just doing 'contact_email' instead. Except that now it's 'emails'
				# serialize: (router, context) ->
				# 	identity: context.get 'email'
				# deserialize: (router, params) ->
				# 	# Dynamic segment can be a document id or an email. Emails make more meaningful forward-facing links.
				# 	identity = params.identity
				# 	if validators.isEmail identity
				# 		return App.Contact.find(email: identity)
				# 	App.Contact.find identity

			contacts: Ember.Route.extend
				route: '/contacts'
				connectOutlets: (router) ->
					router.connectem 'contacts'
					###
					fullContent = Ember.ArrayProxy.create Ember.SortableMixin,
						content: App.Contact.find(added: $exists: true)
						sortProperties: ['added']
						sortAscending: false
					router.get('contactsController').set 'content', fullContent
					###

			leaderboard: Ember.Route.extend
				route: '/leaderboard'
				connectOutlets: (router) ->
					router.connectem 'leaderboard', App.User.find()

			tags: Ember.Route.extend
				route: '/tags'
				connectOutlets: (router) ->
					router.connectem 'tags'
					socket.emit 'tags.stats', (stats) =>
						for stat in stats
							stat.mostRecent = require('moment')(stat.mostRecent).fromNow()
						router.get('tagsController').set 'stats', stats

			report: Ember.Route.extend
				route: '/report'
				connectOutlets: (router) ->
					router.connectem 'report'


			userProfile: Ember.Route.extend
				route: '/profile'
				connectOutlets: (router) ->
					router.connectem 'profile', App.user
					router.get('profileController').set 'self', true

			create: Ember.Route.extend
				route: '/create'
				connectOutlets: (router) ->
					router.connectem 'create'

			classify: Ember.Route.extend
				route: '/classify'
				connectOutlets: (router) ->
					router.connectem 'classify'
					router.get('classifyController').connectOutlet 'contact'

			import: Ember.Route.extend
				route: '/import'
				connectOutlets: (router) ->
					router.connectem 'import'


			load: Ember.Route.extend
				route: '/load'	# Public for the authorization flow.
				enter: (manager) ->
					# TO-DO probably set a session variable or something to ensure loading doesn't happen twice by back button or anything.
					view = App.LoaderView.create()
					view.append()
				redirectsTo: 'userProfile'


			unauthorized: Ember.Route.extend
				route: '/unauthorized'	# Public for the authorization flow.
				enter: (manager) ->
					util.notify
						title: 'Unauthorized'
						text: 'You must grant the requested permissions.'
						before_open: (pnotify) =>
							pnotify.css top: '60px'
				redirectsTo: 'index'

			invalid: Ember.Route.extend
				route: '/invalid'	# Public for the authorization flow.
				enter: (manager) ->
					util.notify
						title: 'Invalid Account'
						text: 'You must use your Redstar account.'
						before_open: (pnotify) =>
							pnotify.css top: '60px'
				redirectsTo: 'index'


			link: Ember.Route.extend
				route: '/link'	# Public url so the http-based linkedin flow can hook in.
				enter: (manager) ->
					view = App.LinkerView.create()
					view.append()
				redirectsTo: 'userProfile'


			goHome: Ember.Route.transitionTo 'index'
			goProfile: Ember.Route.transitionTo 'profile'
			goContact: Ember.Route.transitionTo 'contact'
			goSearch: Ember.Route.transitionTo 'searching'
			goLeaderboard: Ember.Route.transitionTo 'leaderboard'
			goContacts: Ember.Route.transitionTo 'contacts'
			goTags: Ember.Route.transitionTo 'tags'
			goReport: Ember.Route.transitionTo 'report'

			goUserProfile: Ember.Route.transitionTo 'userProfile'
			goCreate: Ember.Route.transitionTo 'create'
			goClassify: Ember.Route.transitionTo 'classify'
			goImport: Ember.Route.transitionTo 'import'


			doLogout: (router, context) ->
				socket.emit 'logout', ->
					App.auth.logout()
					router.transitionTo 'index'

			doIntercept: (router, context) ->
				util.notify
					title: 'Please log in'
					text: 'Then we\'ll send you to your page.'
					before_open: (pnotify) =>
						pnotify.css top: '60px'
				router.transitionTo 'index'
