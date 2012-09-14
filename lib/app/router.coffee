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


			load: Ember.Route.extend
				route: '/load'	# This state only has a public url so the http-based authorize flow can hook in.
				enter: (manager) ->
					socket.emit 'session', 'user', (id) ->	# TODO XXX hack, just use App.user id when possible
						socket.emit 'parse', id, ->
						# TODO XXX do the loader
					App.authenticate()	# TODO XXX might need to go to userProfile after authorization happens; then this can't be a route
				redirectsTo: 'userProfile'


			goHome: Ember.Route.transitionTo 'home'
			goUserProfile: Ember.Route.transitionTo 'userProfile'
			goContact: Ember.Route.transitionTo 'contact'
			goTags: Ember.Route.transitionTo 'tags'
			goReport: Ember.Route.transitionTo 'report'

		# location: 'history'	# TODO Also rework server/index to serve index.html on any route (where currently "next new util.NotFound") WITHOUT
								# REDIRECTING (preserve the route for ember) and make all 3 error pages be part of ember somehow. Keep the server
								# error page however. Can I capture ember errors and serve a special page?
		enableLogging: true	# TODO
