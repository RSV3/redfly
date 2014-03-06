module.exports = (Ember, App) ->
	_ = require 'underscore'
	_s = require 'underscore.string'

	util = require './util.coffee'
	socketemit = require './socketemit.coffee'

	recent_query_string = ''	# this is the query that returns the list of all contacts

	App.Router.reopen
		location: 'history'
		connectem: (route, name)->
			if not App.user?.get('id')
				if name isnt 'index'
					util.notify
						title: 'Session Cleared'
						text: 'You must login to access Redfly.'
						before_open: (pnotify) ->
							pnotify.css top: '60px'
				name = 'index'

			if name is 'index' then return route.render name,
				into: 'application'
				outlet:'panel'

			appname = if name is 'requests' then 'app2' else 'app1'
			route.render appname,
				into: 'application'
				outlet: 'panel'

			if name in ['results', 'responses']
				route.render 'filter',
					into: appname
					outlet: 'sidebar'
					controller: name
			else if name in ['classify', 'enrich']
				route.render 'leaders',
					into: appname
					outlet: 'sidebar'
					controller: 'leaders'
			else if name is 'requests'
				route.render 'pastreqs',
					into: appname
					outlet: 'sidebar'
					controller: 'pastreqs'
			else
				route.render 'feed',
					into: appname
					outlet: 'sidebar'
					controller: 'feed'
			if name is 'enrich' then name = 'results'
			route.render name,
				into: appname
				outlet: 'main'
				controller: name

	App.Router.map ->
		@route 'profile', path: '/profile/:user_id'
		@route 'contact', path: '/contact/:contact_id'
		@route 'contacts'
		@route 'leaderboard'
		@route 'requests'
		@resource 'results', path: '/results/:query_text'
		@route 'responses', path: '/responses/:request_id'
		@route 'noresult', path: '/results'
		@route 'allresults', path: '/results/'
		@route 'enrich', path: '/enrich'
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
				socketemit.post 'logout', =>
					App.auth.logOnOut()
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
			if App.user?.get('admin')
				socketemit.get 'stats', (stats)=>
					for own key,val of stats
						controller.set key, val
					@store.find('admin', 1).then (admin)->
						controller.set 'content', admin
			else @transitionTo 'userProfile'
		renderTemplate: ->
			@router.connectem @, 'admin'

	App.ImportRoute = Ember.Route.extend
		renderTemplate: -> @router.connectem @, 'import'

	App.CreateRoute = Ember.Route.extend
		renderTemplate: -> @router.connectem @, 'create'

	App.DashboardRoute = Ember.Route.extend
		setupController: (controller) ->
			if App.user?.get('admin')
				socketemit.get 'dashboard', (board)->
					controller.set 'dash', board
			else @transitionTo 'userProfile'
		renderTemplate: ->
			@router.connectem @, 'dashboard'

	App.ClassifyRoute = Ember.Route.extend
		setupController: (controller, model) ->
			controller.set 'model', null
			controller.set 'dynamicQ', null
			controller.set 'complete', false
			controller.set 'classifyCount', 0
			socketemit.get "classifyQ/#{App.user?.get('id')}", (results) =>
				if results and results.length
					App.admin.set 'classifyCount', results.length
					controller.set 'dynamicQ', @store.find 'contact', results
				else @transitionTo 'recent'
		renderTemplate: ->
			@router.connectem @, 'classify'

	App.ContactsRoute = Ember.Route.extend
		setupController: (controller, model) ->
			controller.set 'addedContacts', null
			controller.set 'page1Contacts', @store.find 'contact', {
				conditions: added: $exists: true
				options:
					sort: added: -1
					limit: 10
			}
		renderTemplate: ->
			@router.connectem @, 'contacts'

	App.AllresultsRoute = Ember.Route.extend
		redirect: ->
			newResults = App.Results.create {text: recent_query_string}
			@transitionTo 'results', newResults

	App.NoresultRoute = Ember.Route.extend
		redirect: ->
			util.notify
				title: 'No results found'
				text: 'Reverting to all results.'
				before_open: (pnotify) ->
					pnotify.css top: '60px'
			newResults = App.Results.create {text: recent_query_string}
			@transitionTo 'results', newResults

	App.RecentRoute = Ember.Route.extend
		redirect: ->
			newResults = App.Results.create {text: recent_query_string}
			@transitionTo 'results', newResults

	App.CompaniesRoute = Ember.Route.extend
		setupController: (controller) ->
			controller.set 'all', null
			socketemit.get 'companies', (results)->
				controller.set 'all', results
		renderTemplate: ->
			@router.connectem @, 'companies'

	App.ResponsesRoute = Ember.Route.extend
		model: (params)->
			{ req: params.request_id }
		serialize: (model, param) ->
			request_id: model.req
		deserialize: (param) ->
			qt = decodeURIComponent param.request_id
			{ req: qt }
		setupController: (controller, model) ->
			@_super controller, model
			# easy init
			store = @store
			controller.set 'hasResults', false
			controller.set 'dontFilter', true
			for nullit in ['all', 'f_knows', 'f_indtags', 'f_orgtags', 'sortType']
				controller.set nullit, null
			for zeroit in ['page', 'industryOp', 'orgOp', 'sortDir']
				controller.set zeroit, 0
			controller.set 'empty', false
			controller.set 'staticSearchTag', true
			# find responses
			store.find('request', model.req).then (req)->
				req.get('response').then (resps)->
					Ember.RSVP.all(resps.getEach('contact')).then (lookups)->
						controller.set 'storeLinks', resps.filter (r)-> not r.get('contact.length') and r.get('body.length') and util.isLIURL r.get('body')
						controller.set 'storeComments', resps.filter (r)-> not r.get('contact.length') and r.get('body.length') and not util.isLIURL r.get('body')
						lookups = _.uniq _.flatten _.map(lookups, (l)-> l.getEach 'id')
						unless lookups?.length
							controller.set 'all', []
							controller.set 'hasResults', true
							controller.set 'searchtag', req.get 'text'
						else
							query = _id:$in:lookups
							socketemit.get 'fullSearch', query, (results)->
								unless results.response?.length then controller.set 'all', []
								else
									controller.set 'dontFilter', false
									for own key, val of results
										if key is 'facets'
											for own k, v of results.facets
												controller.set "#{k}_enuff", v.length > 7
												controller.set "f_#{k}", v[0...7]
										else if key isnt 'response'
											controller.set key, val
									controller.set 'all', store.find 'contact', lookups
								controller.set 'query', query
								controller.set 'hasResults', true
								controller.set 'searchtag', req.get 'text'

		renderTemplate: ->
			@router.connectem @, 'responses'

	App.ResultsRoute = Ember.Route.extend
		model: (params) ->
			{ text: params.query_text }
		serialize: (model, param) ->
			o = query_text: model.text
			if model.poor then o.poor = true
			o
		deserialize: (param) ->
			qt = decodeURIComponent param.query_text
			if not qt?.length then qt = recent_query_string
			{ text: qt }
		setupController: (controller, model) ->
			@_super controller, model
			for nullit in ['all', 'f_knows', 'f_indtags', 'f_orgtags', 'sortType']
				controller.set nullit, null
			for zeroit in ['page', 'industryOp', 'orgOp', 'sortDir']
				controller.set zeroit, 0
			controller.set 'empty', false

			query = query:model.text
			if model.poor
				controller.set 'datapoor', true
				query.moreConditions = poor:true
			socketemit.get 'fullSearch', query, (results) =>
				if results and results.query is model.text		# ignore stale results that don't match the query
					if not results.response?.length
						if model.text isnt recent_query_string then return @transitionTo 'noresult'
						else return @transitionTo 'userProfile'
					for own key, val of results
						if key is 'facets'
							for own k, v of results.facets
								controller.set "#{k}_enuff", v.length > 7
								controller.set "f_#{k}", v[0..7]
						else if key isnt 'response'
							controller.set key, val
					if results.query?.length and results.query isnt recent_query_string
						controller.set 'searchtag', results.query
					controller.set 'all', @store.find 'contact', results.response
		renderTemplate: ->
			@router.connectem @, 'results'

	App.EnrichRoute = Ember.Route.extend
		redirect: ->
			poorResults = App.Results.create {text: '', poor:true}
			@transitionTo 'results', poorResults

	App.RequestsRoute = Ember.Route.extend
		setupController: (controller, model)->
			socketemit.get 'requests', (reqs, theresmore)->
				if reqs
					controller.set 'hasNext', theresmore
					if theresmore then controller.set 'pageSize', reqs.length
					controller.set 'reqs', controller.store.find 'request', reqs
		renderTemplate: ->
			@router.connectem @, 'requests'


	App.LeaderboardRoute = Ember.Route.extend
		setupController: (controller, model) ->
			store = @store
			socketemit.get 'leaderboard', (rankday, lowest, leaders, laggards, datapoor) ->
				console.dir leaders
				console.dir laggards
				controller.set 'rankday', rankday
				controller.set 'lowest', lowest
				controller.set 'leader', store.find 'user', leaders
				controller.set 'laggard', store.find 'user', laggards
				controller.set 'datapoor', datapoor
		renderTemplate: ->
			@router.connectem @, 'leaderboard'

	App.TagsRoute = Ember.Route.extend
		# This would be a bit cleaner if we used 'model' instead of 'setupController' and called the stats the model.
		setupController: (controller) ->
			socketemit.get 'tags.stats', (stats) ->
				for stat in stats
					stat.mostRecent = require('moment')(stat.mostRecent).fromNow()
				controller.set 'stats', stats
		renderTemplate: ->
			@router.connectem @, 'tags'

	App.UserProfileRoute = Ember.Route.extend
		model: ->
			App.user
		setupController: (controller, model) ->
			@_super controller, model
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
			@transitionTo 'userProfile'
			###
			# this was interfering with the activation
			redirect: ->
				@transitionTo 'userProfile'
			renderTemplate: ->
				@router.connectem @, 'profile'
			###

	App.UnauthorizedRoute = Ember.Route.extend
		activate: ->
			util.notify
				title: 'Unauthorized'
				text: 'You must grant the requested permissions.'
				before_open: (pnotify) ->
					pnotify.css top: '60px'
		redirect: ->
			@transitionTo 'index'
		renderTemplate: ->
			@router.connectem @, 'index'

	App.InvalidRoute = Ember.Route.extend
		activate: ->
			util.notify
				title: 'Invalid Account'
				text: "You must use your organisational account."
				before_open: (pnotify) ->
					pnotify.css top: '60px'
		redirect: ->
			@transitionTo 'index'

	App.IndexRoute = Ember.Route.extend
		renderTemplate: ->
			@router.connectem @, 'index'
		redirect: ->
			if App.user?.get('id') then @transitionTo 'recent'

	App.LinkRoute = Ember.Route.extend
		activate: ->
			view = App.LinkerView.create()
			view.append()
			@transitionTo 'userProfile'
			###
			# this was interfering with the activation
			redirect: ->
				@transitionTo 'userProfile'
			renderTemplate: ->
				@router.connectem @, 'profile'
			###


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
