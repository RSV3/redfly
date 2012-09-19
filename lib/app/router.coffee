# validators = require('validator').validators	# TODO 'net' not found?
validators = {}
validators.isEmail = (email) ->
	_s = require 'underscore.string'
	_s.contains email, '@'



module.exports = (Ember, App, socket) ->
	_s = require 'underscore.string'
	util = require './util'


	App.Router = Ember.Router.extend
		root: Ember.Route.extend
			home: Ember.Route.extend
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
				# serialize: (router, context) ->
				# 	identity: context.get 'email'
				# deserialize: (router, params) ->
				# 	# Dynamic segment can be a document id or an email. Emails make more meaningful forward-facing links.
				# 	identity = params.identity
				# 	if validators.isEmail identity
				# 		return App.Contact.find(email: identity).objectAt 0
				# 	App.Contact.find identity

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
					router.get('applicationController').connectOutlet 'classify', App.user # TODO is there going to be a template for classify or reuse profile??


			load: Ember.Route.extend
				route: '/load'	# Public url so the http-based authorize flow can hook in.
				enter: (manager) ->
					view = App.LoaderView.create()
					view.append()
					# socket.emit 'session', (session) ->	# TODO XXX hack
					# 	socket.emit 'parse', session.user, ->
					# 		# TODO XXX do the loader
				redirectsTo: 'userProfile'	# Free authentication because this the user only arrvies at this route from off the app.


			goHome: Ember.Route.transitionTo 'home'
			goContact: Ember.Route.transitionTo 'contact'
			goTags: Ember.Route.transitionTo 'tags'
			goReport: Ember.Route.transitionTo 'report'

			goUserProfile: Ember.Route.transitionTo 'userProfile'
			goClassify: Ember.Route.transitionTo 'classify'


			doSignup: (router, context) ->
				if identity = _s.trim App.user.get 'signupIdentity'
					App.user.set 'signupIdentity', null
					socket.emit 'signup', util.identity(identity), (authorizeUrl) ->
						# if not authorizeUrl
						# 	# TODO give an error message if there's already a user with that email.
						window.location.href = authorizeUrl				

			doLogin: (router, context) ->
				if identity = _s.trim App.user.get 'loginIdentity'
					App.user.set 'loginIdentity', null
					socket.emit 'login', util.identity(identity), (id) ->
						# if not id
						# 	# TODO give an error message if the user wasn't found.
						App.auth.login id
						router.transitionTo 'userProfile'

			doLogout: (router, context) ->
				socket.emit 'logout', ->
					App.auth.logout()
					router.transitionTo 'home'


		# location: 'history'	# TODO Also rework server/index to serve index.html on any route (where currently "next new util.NotFound") WITHOUT
								# REDIRECTING (preserve the route for ember) and make all 3 error pages be part of ember somehow. Keep the server
								# error page however. Can I capture ember errors and serve a special page? Replace all instances of /#
		enableLogging: true	# TODO
