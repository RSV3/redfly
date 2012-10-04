module.exports = (Ember, App, socket) ->
	util = require './util'
	tools = require '../util'


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
				# TODO try just doing 'contact_email' instead. Except that now it's 'emails'
				# serialize: (router, context) ->
				# 	identity: context.get 'email'
				# deserialize: (router, params) ->
				# 	# Dynamic segment can be a document id or an email. Emails make more meaningful forward-facing links.
				# 	identity = params.identity
				# 	if validators.isEmail identity
				# 		return App.Contact.find(email: identity)
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
					index = App.user.get 'classifyIndex'
					contact = App.user.get('classifyQueue').objectAt index
					App.classify.set 'content', contact

					router.get('applicationController').connectOutlet 'classify', App.classify
					router.get('classifyController').connectOutlet 'contact', App.classify

					App.store.findQuery App.Contact, {}	# TODO hack to refresh the contacts, not sure why user.classifyQueue doesn't get loaded


			load: Ember.Route.extend
				route: '/load'	# Public url so the http-based authorize flow can hook in.
				enter: (manager) ->
					# TO-DO probably set a session variable or something to ensure loading doesn't happen twice by back button or anything.
					view = App.LoaderView.create()
					view.append()
				redirectsTo: 'userProfile'


			goHome: Ember.Route.transitionTo 'home'
			goProfile: Ember.Route.transitionTo 'profile'
			goContact: Ember.Route.transitionTo 'contact'
			goTags: Ember.Route.transitionTo 'tags'
			goReport: Ember.Route.transitionTo 'report'

			goUserProfile: Ember.Route.transitionTo 'userProfile'
			goClassify: Ember.Route.transitionTo 'classify'


			doSignup: (router, context) ->
				if identity = tools.trim App.user.get 'signupIdentity'
					App.user.set 'signupIdentity', null
					socket.emit 'signup', util.identity(identity), (authorizeUrl) ->
						# if not authorizeUrl
							
						window.location.href = authorizeUrl				

			doLogin: (router, context) ->
				if identity = tools.trim App.user.get 'loginIdentity'
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
