module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'
	util = require './util'

	App.Router.reopen
		location: 'history'
		connectem: (route, name)->
			if not App.user.get('id')
				if name isnt 'index'
					util.notify
						title: 'Session Cleared'
						text: 'You must login to access Redfly.'
						before_open: (pnotify) =>
							pnotify.css top: '60px'
				name = 'index'
			if name is 'results'
				route.render 'filter',
					into: 'application'
					outlet: 'sidebar'
					controller: 'results'
			else
				route.render 'feed',
					into: 'application'
					outlet: 'sidebar'
					controller: 'feed'
			route.render name,
				into: 'application'
				outlet: 'main'
				controller: name

	App.Router.map ->
		@route 'profile', path: '/profile/:user_id'
		@route 'contact', path: '/contact/:contact_id'
		@route 'contacts'
		@route 'leaderboard'
		@resource 'results', path: '/results/:query_text'
		@route 'noresults', path: '/results'
		@route 'noresults', path: '/results/'
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

		@route 'recent'
		@route 'companies'

	App.ApplicationRoute = Ember.Route.extend
		events:
			logout: (context) ->
				socket.emit 'logout', =>
					App.auth.logout()
					@transitionTo 'index'

	App.ProfileRoute = Ember.Route.extend
		setupController: (controller, model) ->
			controller.set 'content', model
		renderTemplate: ->
			@router.connectem @, 'profile'

	App.ContactRoute = Ember.Route.extend
		setupController: (controller, model) ->
			controller.set 'content', model
		renderTemplate: ->
			@router.connectem @, 'contact'

	App.AdminRoute = Ember.Route.extend
		setupController: (controller) ->
			if App.user.get('admin')
				controller.set 'content', App.Admin.find 1
				controller.set 'category', 'industry'
			else @transitionTo 'userProfile'
		renderTemplate: ->
			@router.connectem @, 'admin'

	App.DashboardRoute = Ember.Route.extend
		setupController: (controller) ->
			if App.user.get('admin')
				socket.emit 'dashboard', (board)=>
					controller.set 'dash', board
			else @transitionTo 'userProfile'
		renderTemplate: ->
			@router.connectem @, 'dashboard'

	App.ClassifyRoute = Ember.Route.extend
		setupController: (controller, model) ->
			controller.set 'model', null
			socket.emit 'classifyQ', App.user.get('id'), (results) =>
				if results and results.length
					controller.set 'classifyCount', 0
					controller.set 'dynamicQ', App.store.findMany(App.Contact, results)
				else @transitionTo 'recent'
		renderTemplate: ->
			@router.connectem @, 'classify'

	App.ContactsRoute = Ember.Route.extend
		setupController: (controller, model) ->
			controller.set 'addedContacts', null
			controller.set 'page1Contacts', App.Contact.find {
				conditions: added: $exists: true
				options:
					sort: added: -1
					limit: 10
			}
		renderTemplate: ->
			@router.connectem @, 'contacts'

	App.NoresultsRoute = Ember.Route.extend
		redirect: ->
			util.notify
				title: 'No results found'
				text: 'Reverting to all results.'
				before_open: (pnotify) =>
					pnotify.css top: '60px'
			newResults = App.Results.create {text: "contact:0"}
			@transitionTo 'results', newResults

	App.RecentRoute = Ember.Route.extend
		redirect: ->
			newResults = App.Results.create {text: "contact:0"}
			@transitionTo 'results', newResults

	App.CompaniesRoute = Ember.Route.extend
		setupController: (controller) ->
			controller.set 'all', null
			socket.emit 'companies', (results)=>
				controller.set 'all', results
		renderTemplate: ->
			@router.connectem @, 'companies'

	App.ResultsRoute = Ember.Route.extend
		model: (params) ->
			{ text: params.text }
		serialize: (model, param) ->
			{ query_text: model.text}
		deserialize: (param) ->
			qt = decodeURIComponent param.query_text
			if not qt?.length then qt = 'contact:0'
			{ text: qt }
		setupController: (controller, model) ->
			this._super controller, model
			controller.set 'all', null
			socket.emit 'fullSearch', query: model.text, (results) =>
				if results and results.query is model.text		# ignore stale results that don't match the query
					if not results.response?.length then return @transitionTo 'recent'
					for own key, val of results
						controller.set key, results[key]
					controller.set 'sortDir', 0
					controller.set 'sortType', null
					controller.set 'all', App.store.findMany(App.Contact, results.response)
		renderTemplate: ->
			@router.connectem @, 'results'

	App.LeaderboardRoute = Ember.Route.extend
		model: ->
			App.User.find()
			App.User.all()
		renderTemplate: ->
			@router.connectem @, 'leaderboard'

	App.TagsRoute = Ember.Route.extend
		# This would be a bit cleaner if we used 'model' instead of 'setupController' and called the stats the model.
		setupController: (controller) ->
			socket.emit 'tags.stats', (stats) =>
				for stat in stats
					stat.mostRecent = require('moment')(stat.mostRecent).fromNow()
				controller.set 'stats', stats
		renderTemplate: ->
			@router.connectem @, 'tags'

	App.UserProfileRoute = Ember.Route.extend
		model: ->
			App.user
		setupController: (controller, model) ->
			this._super controller, model
			controller = @controllerFor 'profile'
			controller.set 'content', model
			controller.set 'self', true
		renderTemplate: ->
			@router.connectem @, 'profile'

	App.LoadRoute = Ember.Route.extend
		activate: ->
			# TO-DO probably set a session variable or something to ensure loading doesn't happen twice by back button or anything.
			view = App.LoaderView.create router: this   # hack
			view.append()
		redirect: ->
			@transitionTo 'userProfile'
		renderTemplate: ->
			@router.connectem @, 'profile'

	App.UnauthorizedRoute = Ember.Route.extend
		activate: ->
			util.notify
				title: 'Unauthorized'
				text: 'You must grant the requested permissions.'
				before_open: (pnotify) =>
					pnotify.css top: '60px'
		redirect: ->
			@transitionTo 'index'
		renderTemplate: ->
			@router.connectem @, 'index'

	App.InvalidRoute = Ember.Route.extend
		activate: ->
			util.notify
				title: 'Invalid Account'
				text: 'You must use your Redstar account.'
				before_open: (pnotify) =>
					pnotify.css top: '60px'
		redirect: ->
			@transitionTo 'index'

	App.IndexRoute = Ember.Route.extend
		renderTemplate: ->
			@router.connectem @, 'index'
		redirect: ->
			if App.user.get('id') then @transitionTo 'recent'

	App.LinkRoute = Ember.Route.extend
		activate: ->
			view = App.LinkerView.create()
			view.append()
		redirect: ->
			@transitionTo 'userProfile'
		renderTemplate: ->
			@router.connectem @, 'profile'


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
	# 		router.transitionToRoute 'index'
	# 	else
 # 			setupContexts.apply this, arguments
