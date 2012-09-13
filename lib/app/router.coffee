# validators = require('validator').validators	# TODO 'net' not found?
validators = {}
validators.isEmail = (email) ->
	_s = require 'underscore.string'
	_s.contains email, '@'



module.exports = (Ember, App) ->

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
				goContact: Ember.Route.transitionTo 'contact'

			profile: Ember.Route.extend
				route: '/profile/:user_id'
				connectOutlets: (router, user) ->
					router.get('applicationController').connectOutlet 'profile', user
				goContact: Ember.Route.transitionTo 'contact'

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

		# location: 'history'	# TODO Also rework server/index to serve index.html on any route (where currently "next new util.NotFound") WITHOUT
								# REDIRECTING (preserve the route for ember) and make all 3 error pages be part of ember somehow. Keep the server
								# error page however. Can I capture ember errors and serve a special page?
		enableLogging: true	# TODO

		goHome: Ember.Route.transitionTo 'home'
		goUserProfile: Ember.Route.transitionTo 'userProfile'
		goTags: Ember.Route.transitionTo 'tags'
		goReport: Ember.Route.transitionTo 'report'
