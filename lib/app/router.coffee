module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'
	util = require './util'

	App.Router.reopen
		location: 'history'

	App.Router.map ->
		@route 'profile', path: '/profile/:user_id'
		@route 'contact', path: '/contact/:contact_id'
		@route 'contacts'
		@route 'leaderboard'
		@resource 'results', path: '/results/:query_text'
		@route 'tags'
		# @route 'report'
		@route 'userProfile', path: '/profile'
		@route 'create'
		@route 'classify'
		@route 'import'
		@route 'admin'
		@route 'dashboard'

		# Public for http-based flows (these routes might have hardcoded references).
		@route 'load'
		@route 'unauthorized'
		@route 'invalid'
		@route 'link'


	App.ApplicationRoute = Ember.Route.extend
		events:
			logout: (context) ->
				socket.emit 'logout', =>
					App.auth.logout()
					@transitionTo 'index'

	App.ProfileRoute = Ember.Route.extend
		setupController: (controller, model) ->
			controller.set 'content', model
	App.ContactRoute = Ember.Route.extend
		setupController: (controller, model) ->
			controller.set 'content', model

	App.AdminRoute = Ember.Route.extend
		setupController: (controller) ->
			if App.user.get('admin')
				controller.set 'content', App.Admin.find 1
				controller.set 'category', 'organisation'
				###
				socket.emit 'tags.stats', (stats) =>
					for stat in stats
						stat.mostRecent = require('moment')(stat.mostRecent).fromNow()
					controller.set 'stats', stats
				###
			else @transitionTo 'userProfile'
	App.DashboardRoute = Ember.Route.extend
		setupController: (controller) ->
			if App.user.get('admin')
				socket.emit 'dashboard', (board)=>
					controller.set 'dash', board
			else @transitionTo 'userProfile'

	App.ClassifyRoute = Ember.Route.extend
		setupController: (controller, model) ->
			controller.set 'model', null
			socket.emit 'classifyQ', App.user.get('id'), (results) =>
				if results and results.length
					controller.set 'classifyCount', 0
					controller.set 'dynamicQ', App.store.findMany(App.Contact, results)
				else @transitionTo 'userProfile'

	App.ContactsRoute = Ember.Route.extend
		setupController: (controller, model) ->
			controller.set 'addedContacts', null
			controller.set 'page1Contacts', App.Contact.find {
				conditions: added: $exists: true
				options:
					sort: added: -1
					limit: 10
			}

	App.ResultsRoute = Ember.Route.extend
		model: (params) ->
			{ text: params.text }
		serialize: (model, param) ->
			{ query_text: model.text}
		deserialize: (param) ->
			{ text: decodeURIComponent param.query_text }
		setupController: (controller, model) ->
			socket.emit 'fullSearch', query: model.text, (results) =>
				if results
					if results.query is model.text	# ignore stale results that don't match the query
						if not results.response?.length then @transitionTo 'userProfile'
						else controller.set 'all', App.store.findMany(App.Contact, results.response)

	App.LeaderboardRoute = Ember.Route.extend
		model: ->
			App.User.find()
			App.User.all()
	App.TagsRoute = Ember.Route.extend
		# This would be a bit cleaner if we used 'model' instead of 'setupController' and called the stats the model.
		setupController: (controller) ->
			socket.emit 'tags.stats', (stats) =>
				for stat in stats
					stat.mostRecent = require('moment')(stat.mostRecent).fromNow()
				controller.set 'stats', stats
	App.UserProfileRoute = Ember.Route.extend
		model: ->
			App.user
		# This is kind of ugly. Might be better to use App.inject to make userProfileController map to profileController.
		setupController: (controller, model) ->
			controller = @controllerFor 'profile'
			controller.set 'content', model
			controller.set 'self', true
		renderTemplate: ->
			@render 'profile', controller: @controllerFor('profile')
	App.LoadRoute = Ember.Route.extend
		activate: ->
			# TO-DO probably set a session variable or something to ensure loading doesn't happen twice by back button or anything.
			view = App.LoaderView.create router: this   # hack
			view.append()
		redirect: ->
			@transitionTo 'userProfile'
	App.UnauthorizedRoute = Ember.Route.extend
		activate: ->
			util.notify
				title: 'Unauthorized'
				text: 'You must grant the requested permissions.'
				before_open: (pnotify) =>
					pnotify.css top: '60px'
		redirect: ->
			@transitionTo 'index'
	App.InvalidRoute = Ember.Route.extend
		activate: ->
			util.notify
				title: 'Invalid Account'
				text: 'You must use your Redstar account.'
				before_open: (pnotify) =>
					pnotify.css top: '60px'
		redirect: ->
			@transitionTo 'index'
	App.LinkRoute = Ember.Route.extend
		activate: ->
			view = App.LinkerView.create()
			view.append()
		redirect: ->
			@transitionTo 'userProfile'


	# authRequiredRoutes = [
	# 	'profile'
	# 	'contact'
	# 	'contacts'
	# 	'leaderboard'
	# 	'tags'
	# 	'userProfile'
	# 	'classify'
	# 	'import'
	# 	'load'
	# 	'link'
	# ]

	# intercepted = null

	# setupContexts = App.Router::setupContexts
	# App.Router::setupContexts = (router, handlerInfos) ->
	# 	_ = require 'underscore'
	# 	authRequired = _.find handlerInfos, (info) ->
	# 		info.name in authRequiredRoutes
	# 	authenticated = App.user.get 'content'
	# 	if authRequired and not authenticated
	# 		intercepted = handlerInfos
	# 		util.notify
	# 			title: 'Please log in'
	# 			text: 'Then we\'ll send you to your page.'
	# 			before_open: (pnotify) =>
	# 				pnotify.css top: '60px'
	# 		router.transitionTo 'index'
	# 	else
 # 			setupContexts.apply this, arguments
