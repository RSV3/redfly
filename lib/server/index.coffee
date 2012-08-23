http = require 'http'
path = require 'path'
express = require 'express'
gzippo = require 'gzippo'
derby = require 'derby'
mongo = require 'racer-db-mongo'

# RedisStore = require('connect-redis')(express)

_ = require 'underscore'

app = require '../app'
util = require '../util'



expressApp = express()
server = module.exports = http.createServer expressApp

derby.use derby.logPlugin
# derby.use mongo
store = derby.createStore
	listen: server
	# db: type: 'Mongo', uri: process.env.MONGOLAB_URI

# Heroku doesn't support websockets, force long polling.
store.io.configure ->
	store.io.set 'transports', ['xhr-polling']
	store.io.set 'polling duration', 10

myapp = store.io.of('/myapp/loader').on 'connection', (socket) ->
	socket.on 'parse', (id, fn) ->
		model = store.createModel()
		model.fetch 'users.' + id, (err, userModel) ->
			throw err if err
			user = userModel.get()
			notifications =
				foundName: (name) ->
					userModel.set 'name', name	# TODO XXX user name setting isn't working OR IS IT
				foundTotal: (total) ->
					socket.emit 'start', total
				completedEmail: ->
					socket.emit 'update'
				done: (newContacts) ->
					for newContact in newContacts
						model.fetch model.query('contacts').findByEmail(email), (err, contactModel) ->
							throw err if err
							contact = contactModel.get()
							# If the contact doesn't exist yet, just go ahead and add it!
							if not contact
								newContact.id = model.id()
								model.set 'contacts.' + newContact.id, newContact
							# If the contact does exist, merge our new data into it.
							else
								knowsModel = model.at contactModel.path() + '.knows.' + user.id
								knows = newContact.knows[user.id]
								if not knowsModel.get()
									knowsModel.set knows
								else
									knowsModel.incr 'count', knows.count

					userModel.set 'last_parse_date', +new Date
					# Callback to the 'parse' event, to tell the frontend parsing indicator we're all done here.
					fn()
			require('../parser')(user, notifications)


store.query.expose 'users', 'findByEmail', (email) ->
	@where('email').equals(email).one()

store.query.expose 'contacts', 'findByEmail', (email) ->
	@where('email').equals(email).one()

store.query.expose 'contacts', 'addedBy', (user) ->
	# Arguement can be a user object or just and ID.	# Maybe also allow a Derby model?
	if _.isObject user
		user = user.id
	@where('added_by').equals(user)

# TODO XXX comment these out
model = store.createModel()
model.set 'contacts.178.name', 'John Resig'
model.set 'contacts.178.email', 'john@name.com'
model.set 'contacts.178.date', +new Date
model.set 'contacts.178.added_by', '178'
model.set 'contacts.178.date_added', +new Date
model.set 'contacts.178.knows.178',
		first_email:
			date: +new Date
			subject: 'Poopty Peupty pants'
		count: 47
model.push 'contacts.178.tags', 'Sweet Tag Bro'
model.push 'contacts.178.tags', 'VC'
model.push 'contacts.178.notes',
	date: +new Date
	text: 'Lorem ipsum dolor ist asdf asdfadf dasf adsf adsf adsf asdfads fads fads'
	author: '178'
model.push 'contacts.178.notes',
	date: +new Date
	text: 'asdf ipsum dolor ist asdf asdfadf dasf adsf adsf adsf asdfads fads fads'
	author: '178'
# model.set 'users.178.email', 'kbaranowski@redstar.com'
# model.set 'users.178.name', 'Krzysztof Baranowski'

ONE_YEAR = 1000 * 60 * 60 * 24 * 365
root = path.dirname path.dirname __dirname

staticPages = derby.createStatic root

expressApp.configure ->
	# Mail template rendering.
	expressApp.set 'views', root + '/mail'
	expressApp.set 'view engine', 'jade'
	expressApp.locals.pretty = true

	expressApp.use (req, res, next) ->
		if req.headers.host isnt process.env.HOST
			url = req.protocol + process.env.HOST + req.url
			res.writeHead 301, Location: url
			return res.end()
		next()
	# expressApp.use express.logger('dev')
	# expressApp.use express.profiler()
	expressApp.use express.favicon(root + '/resources/favicon.ico')
	# expressApp.use gzippo.staticGzip(path.join(root, 'public'), maxAge: ONE_YEAR)
	expressApp.use express.static(path.join(root, 'public'))
	# expressApp.use express.compress()

	expressApp.use express.bodyParser()
	expressApp.use express.methodOverride()

	expressApp.use express.cookieParser('cat on a keyboard in space')
	expressApp.use store.sessionMiddleware
		secret: 'cat on a keyboard in space'	# TODO remove probably, secret is in cookieParser with newer versions of express
		cookie: maxAge: ONE_YEAR
		# store: new RedisStore do ->
		# 	parse = require('url').parse
		# 	redisToGo = parse process.env.REDISTOGO_URL
		# 	host: redisToGo.hostname
		# 	port: redisToGo.port
		# 	pass: redisToGo.auth.split(':')[1]
	expressApp.use store.modelMiddleware()

	# expressApp.use (req, res, next) ->	# TODO Bring this back if it still applies.
	# 	if process.env.AUTO_AUTH
	# 		req.session.user = '178'
	# 	next()
	expressApp.use app.router()
	expressApp.use expressApp.router

	expressApp.use (req, res, next) ->
		next new util.NotFound
	expressApp.use (err, req, res, next) ->
		if err instanceof util.NotFound
			staticPages.render 'not_found', res, 404
		else if err instanceof util.AccessDenied
			staticPages.render 'access_denied', res, 403
		else
			next err

expressApp.configure 'development', ->
	expressApp.use express.errorHandler()

expressApp.configure 'production', ->
	expressApp.use (err, req, res, next) ->
		# TODO maybe send error email to myself here, or just check the logs. Consider attaching to 'uncaughtException' too.
		staticPages.render 'error', res, 500



# Server-only routes.

login = (req, id, res) ->
	req.getModel().session.user = id
	# TODO session/cookie hack, get rid of 'res' param
	res.cookie 'user', id

logout = (req) ->
	delete req.getModel().session.user # TODO XXX try logging out
	# req.getModel().session.destroy()	# TODO see if destorying the session is okay (derby puts some stuff there), or if this even works. Try conssole.dir req.getModel().session and see if there's a destroy method.

expressApp.post '/login', (req, res) ->
	# If the user has never logged in before, redirect to gmail oauth page. Otherwise, log in.
	model = req.getModel()
	email = req.body.email
	model.fetch model.query('users').findByEmail(email), (err, userModel) ->
		throw err if err
		user = userModel.get()
		# TODO do authentication, either openID or: if user and user.password is req.body.password
		if user
			login req, user.id, res
			res.send()
		else
			oauth = require 'oauth-gmail'
			client = oauth.createClient callbackUrl: 'http://' + process.env.HOST + '/authorized'
			client.getRequestToken email, (err, result) ->  # TODO XXX try mistyping an email and see what happens
				throw err if err
				model.session.authorizeData = email: email, request: result
				res.send result.authorizeUrl

expressApp.get '/logout', (req, res) ->
	logout req
	res.redirect '/'

expressApp.get '/authorized', (req, res) ->
	model = req.getModel()
	data = model.session.authorizeData
	delete model.session.authorizeData

	oauth = require 'oauth-gmail'
	client = oauth.createClient()
	client.getAccessToken data.request, req.query.oauth_verifier, (err, result) ->
		throw err if err

		# Create the user and log him in.
		id = model.id()
		user =
			id: id
			date: +new Date
			email: data.email
			oauth:
				token: result.accessToken
				secret: result.accessTokenSecret
		model.set 'users.' + id, user
		login req, id, res

		res.redirect('/profile?signup=true')
