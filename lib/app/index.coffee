_ = require 'underscore'
moment = require 'moment'
derby = require 'derby'

{get, view, ready} = derby.createApp module

derby.use(require '../../ui')


view.fn 'date', (date) ->
	moment(date).format('MMMM Do, YYYY')


get '*', (page, model, params, next) ->
	# TODO XXX
	# model.subscribe 'contacts', (err, contacts) ->
	# 	throw err if err
	# 	model.ref '_recentContacts', model.sort('contacts', 'date')
	model.subscribe 'contacts.178', (err, contact) ->
		throw err if err
		model.ref '_recentContact', contact

		userId = model.session.user
		if userId
			model.subscribe 'users.' + userId, (err, user) ->
				throw err if err
				model.ref '_user', user

				next()	# TODO XXX does this need to be scoped?
		else
			next()	# TODO XXX does this need to be scoped?

get '/authorized', (page, model, params, next) ->
	data = model.session.authorizeData
	delete model.session.authorizeData

	oauth = require 'oauth-gmail'
	client = oauth.createClient()
	client.getAccessToken data.request, params.query.oauth_verifier, (err, result) ->
		throw err if err
		xoauthString = client.xoauthString data.email, result.accessToken, result.accessTokenSecret

		# TODO XXX add pines notify, then use websockets to update the notifier with background parsing status, then give link to /classify

		# TODO XXX make profile page where it dumps the user when they're done with the signup, and have a success message there that says
		# their email will be parsed (check out upper right), they can start classifying when it's done. In the meantime, have a look around!

		# TODO XXX set the username on the user as soon as possible after parsing begins (and probably after creating the actual user) so that

		# TODO XXX when done add user with email and username (gleaned from emails) to the database, and set in session model.session.user and refresh
		# id = model.id()
		# user =
		# 	id: id
		# 	date: +new Date
		# 	email: data.email
		# 	username: 'TODO'
		#	token: xoauthString
		# model.set 'users.' + id, user


ready (model) ->
	@connect = ->
		emailModel = model.at '_email'
		email = emailModel.get()?.trim()
		if email
			model.set '_connectStarted', true
			$.post '/login', email: email, (redirect) ->
				window.location.href = redirect or '/'	# TODO XXX try without '/' redirect. What can be done to make _user refresh?


require './home'
require './contact'
require './search'
require './tags'
require './report'
