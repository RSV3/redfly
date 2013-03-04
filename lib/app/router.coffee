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

		# Public for http-based flows (these routes might have hardcoded references).
		@route 'load'
		@route 'unauthorized'
		@route 'invalid'
		@route 'link'


	# interceptedPath = null	# TO-DO this doesn't work any more, we have to save this to the session to survive auth flow.
	AuthenticatedRoute = Ember.Route.extend
		redirect: ->
			authenticated = App.user.get 'content'
			if not authenticated
				# interceptedPath = path
				util.notify
					title: 'Please log in'
					text: 'Then we\'ll send you to your page.'
					before_open: (pnotify) =>
						pnotify.css top: '60px'
				@transitionTo 'index'

	App.ApplicationRoute = Ember.Route.extend
		events:
			logout: (context) ->
				socket.emit 'logout', =>
					App.auth.logout()
					@transitionTo 'index'

	App.ProfileRoute = AuthenticatedRoute.extend
		setupController: (controller, model) ->
			controller.set 'content', model
	App.ContactRoute = AuthenticatedRoute.extend
		setupController: (controller, model) ->
			controller.set 'content', model
	App.ContactsRoute = AuthenticatedRoute.extend
		setupController: (controller, model) ->
			controller.set 'addedContacts', App.Contact.find(added: $exists: true)
	App.LeaderboardRoute = AuthenticatedRoute.extend
		model: ->
			App.User.find()
			App.User.all()


	App.ResultsRoute = AuthenticatedRoute.extend
		model: (params) ->
			{ text: params.text }
		serialize: (model, param) ->
			{ query_text: model.text}
		deserialize: (param) ->
			{ text: param.query_text }
		setupController: (controller, model) ->
			console.log "setupController"
			socket.emit 'fullSearch', query: model.text, (results) =>
				controller.set 'all', App.Contact.find _id: $in: results


	App.TagsRoute = AuthenticatedRoute.extend
		# This would be a bit cleaner if we used 'model' instead of 'setupController' and called the stats the model.
		setupController: (controller) ->
			socket.emit 'tags.stats', (stats) =>
				for stat in stats
					stat.mostRecent = require('moment')(stat.mostRecent).fromNow()
				controller.set 'stats', stats
	App.UserProfileRoute = AuthenticatedRoute.extend
		model: ->
			App.user
		# This is kind of ugly. Might be better to use App.inject to make userProfileController map to profileController.
		setupController: (controller, model) ->
			controller = @controllerFor 'profile'
			controller.set 'content', model
			controller.set 'self', true
		renderTemplate: ->
			@render 'profile', controller: @controllerFor('profile')
	App.CreateRoute = AuthenticatedRoute.extend()
	App.ClassifyRoute = AuthenticatedRoute.extend()
	App.ImportRoute = AuthenticatedRoute.extend()
	App.LoadRoute = AuthenticatedRoute.extend
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
	App.LinkRoute = AuthenticatedRoute.extend
		activate: ->
			view = App.LinkerView.create()
			view.append()
		redirect: ->
			@transitionTo 'userProfile'
