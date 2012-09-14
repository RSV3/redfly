# validators = require('validator').validators	# TODO 'net' not found?
validators = {}
validators.isEmail = (email) ->
	_s = require 'underscore.string'
	_s.contains email, '@'



module.exports = (Ember, App, socket) ->

	App.Router = Ember.Router.extend
		root: Ember.Route.extend
			home: Ember.Route.extend
				route: '/'
				connectOutlets: (router) ->
					router.get('applicationController').connectOutlet 'home'

			userProfile: Ember.Route.extend
				route: '/profile'
				connectOutlets: (router) ->
					router.get('applicationController').connectOutlet 'profile', App.user

			profile: Ember.Route.extend
				route: '/profile/:user_id'
				connectOutlets: (router, user) ->
					router.get('applicationController').connectOutlet 'profile', user

			contact: Ember.Route.extend
				route: '/contact/:identity'
				connectOutlets: (router, contact) ->
					router.get('applicationController').connectOutlet 'contact', contact
				serialize: (router, context) ->
					identity: context.get 'email'
				deserialize: (router, params) ->
					# The 'identity' parameter can be a document id or an email. Emails make more meaningful forward-facing links.
					identity = params.identity
					if validators.isEmail identity
						return App.Contact.find(email: identity).objectAt 0
					App.Contact.find identity

			tags: Ember.Route.extend
				route: '/tags'
				connectOutlets: (router) ->
					router.get('applicationController').connectOutlet 'tags'

			report: Ember.Route.extend
				route: '/report'
				connectOutlets: (router) ->
					router.get('applicationController').connectOutlet 'report'


			login: Ember.Route.extend
				enter: (manager) ->
					_s = require 'underscore.string'
					if email = _s.trim App.connect.get 'email'
						App.connect.set 'started', true
						# If only the username was typed make it a proper email.

						# validators = require('validator').validators	# TODO 'net' not found?
						validators = {}
						validators.isEmail = (email) ->
							_s = require 'underscore.string'
							_s.contains email, '@'

						if not validators.isEmail email
							email += '@redstar.com'
						socket.emit 'login', email, (signedUp, val) ->
							if not signedUp
								return window.location.href = val
							App.auth val
							# App.get('router').send 'goUserProfile'	# TODO XXX can I redirect from here? Or is somewhere else better?
				exit: (manager) ->	# TODO XXX make sure this gets called when the router is invoked in 'enter'
					App.connect.set 'email', ''
					App.connect.set 'started', false

			logout: Ember.Route.extend
				route: '/logout'
				enter: (manager) ->
					socket.emit 'logout', ->
						App.auth null
						App.get('router').send 'goHome'


			# load: Ember.Route.extend
			# 	route: '/load'	# Public url exists solely so the http-based authorize flow can hook in.
			# TODO XXX start the loader and redirect out to the profile immediately. Load the user with App.auth(),


			goHome: Ember.Route.transitionTo 'home'
			goUserProfile: Ember.Route.transitionTo 'userProfile'
			goContact: Ember.Route.transitionTo 'contact'
			goTags: Ember.Route.transitionTo 'tags'
			goReport: Ember.Route.transitionTo 'report'

			goLogin: Ember.Route.transitionTo 'login'
			goLogout: Ember.Route.transitionTo 'logout'

		# location: 'history'	# TODO Also rework server/index to serve index.html on any route (where currently "next new util.NotFound") WITHOUT
								# REDIRECTING (preserve the route for ember) and make all 3 error pages be part of ember somehow. Keep the server
								# error page however. Can I capture ember errors and serve a special page?
		enableLogging: true	# TODO
