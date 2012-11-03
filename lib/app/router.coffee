module.exports = (Ember, App, socket) ->
	util = require './util'
	tools = require '../util'


	interceptedPath = null

	Ember.Router.reopen
		transitionTo: (path, context) ->
			_ = require 'underscore'

			authenticated = App.user.get 'content'
			state = _.last path.split('.')
			if not authenticated and state not in ['root', 'index']
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
		enableLogging: true	# TODO

		root: Ember.Route.extend
			index: Ember.Route.extend
				route: '/'
				connectOutlets: (router) ->
					router.get('applicationController').connectOutlet 'home'

			profile: Ember.Route.extend
				route: '/profile/:user_id'
				connectOutlets: (router, user) ->
					router.get('applicationController').connectOutlet 'profile', user

			contact: Ember.Route.extend
				# TODO bring back all email serialization, also:
				# http://stackoverflow.com/questions/12064765/initialization-with-serialize-deserialize-ember-js
				# route: '/contact/:identity'
				route: '/contact/:contact_id'
				connectOutlets: (router, contact) ->
					router.get('applicationController').connectOutlet 'contact', contact
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
					router.get('applicationController').connectOutlet 'contacts', App.Contact.find added: $exists: true

			leaderboard: Ember.Route.extend
				route: '/leaderboard'
				connectOutlets: (router) ->
					router.get('applicationController').connectOutlet 'leaderboard', App.User.find()

			tags: Ember.Route.extend
				route: '/tags'
				connectOutlets: (router) ->
					router.get('applicationController').connectOutlet 'tags'

			report: Ember.Route.extend
				route: '/report'
				connectOutlets: (router) ->
					router.get('applicationController').connectOutlet 'report'


			userProfile: Ember.Route.extend
				route: '/profile'
				connectOutlets: (router) ->
					router.get('applicationController').connectOutlet 'profile', App.user

			classify: Ember.Route.extend
				route: '/classify'
				connectOutlets: (router) ->
					contact = Ember.ObjectProxy.create contentBinding: 'App.user.queue.firstObject'
					router.get('applicationController').connectOutlet 'classify'
					router.get('classifyController').connectOutlet 'contact', contact


			load: Ember.Route.extend
				route: '/load'	# Public url so the http-based authorize flow can hook in.
				enter: (manager) ->
					# TO-DO probably set a session variable or something to ensure loading doesn't happen twice by back button or anything.
					view = App.LoaderView.create()
					view.append()
				redirectsTo: 'userProfile'


			goHome: Ember.Route.transitionTo 'index'
			goProfile: Ember.Route.transitionTo 'profile'
			goContact: Ember.Route.transitionTo 'contact'
			goLeaderboard: Ember.Route.transitionTo 'leaderboard'
			goContacts: Ember.Route.transitionTo 'contacts'
			goTags: Ember.Route.transitionTo 'tags'
			goReport: Ember.Route.transitionTo 'report'

			goUserProfile: Ember.Route.transitionTo 'userProfile'
			goClassify: Ember.Route.transitionTo 'classify'


			doSignup: (router, context) ->
				if identity = tools.trim App.user.get 'signupIdentity'
					controller = context.view.get 'controller'
					App.user.set 'signupIdentity', null
					_s = require 'underscore.string'
					if _s.contains(identity, '@') and not _s.endsWith(identity, '@redstar.com')
						return controller.set 'signupError', 'Use your Redstar email kthx.'
					socket.emit 'signup', util.identity(identity), (success, data) ->
						if success
							controller.set 'signupError', null
							window.location.href = data
						else
							controller.set 'signupError', data

			doLogin: (router, context) ->
				if identity = tools.trim App.user.get 'loginIdentity'
					controller = context.view.get 'controller'
					App.user.set 'loginIdentity', null
					socket.emit 'login', util.identity(identity), (success, data) ->
						if success
							controller.set 'loginError', null
							# Temporary use of authorize flow for login.
							window.location.href = data
							# App.auth.login data
							# router.transitionTo interceptedPath or 'userProfile'
							# interceptedPath = null
						else
							controller.set 'loginError', data

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
