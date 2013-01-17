http = require 'http'
path = require 'path'
express = require 'express'
everyauth = require 'everyauth'

passport = require 'passport'

passport.serializeUser (user, done) ->
	done null, user._id

passport.deserializeUser (id, done) ->			# needed to get this setup early
	models = require './models'
	models.User.findOne _id: id, done			# in order to avoid session corruption issue

util = require './util'


app = express()
server = http.createServer app
root = path.dirname path.dirname __dirname
pipeline = require('./pipeline') root

RedisStore = require('connect-redis') express
redisConfig = do ->
	url = require('url').parse process.env.REDISTOGO_URL
	host: url.hostname
	port: url.port
	pass: url.auth.split(':')[1]
key = 'express.sid'
store = new RedisStore redisConfig

everyauth.google.authQueryParam({ access_type:'online', approval_prompt:'auto' });
everyauth.google.configure
	appId: process.env.GOOGLE_API_ID
	appSecret: process.env.GOOGLE_API_SECRET
	entryPath: '/authorize'
	callbackPath: '/authorized'
	scope: [
			'https://www.googleapis.com/auth/userinfo.profile'
			'https://www.googleapis.com/auth/userinfo.email'
			'https://mail.google.com/'
			'https://www.google.com/m8/feeds'
		].join ' '
	handleAuthCallbackError: (req, res) ->
		res.redirect '/unauthorized'
	findOrCreateUser: (session, accessToken, accessTokenExtra, googleUserMetadata) ->
		_s = require 'underscore.string'
		models = require './models'

		email = googleUserMetadata.email.toLowerCase()
		if not _s.endsWith(email, '@redstar.com')
			return {}
		models.User.findOne email: email, (err, user) ->
			throw err if err
			# throw new Error('No refresh token!') if not accessTokenExtra.refresh_token	# TODO remove this line when I'm convinced I always get a token.
			if user
				# promise.fulfill user
				# TEMPORARY ########## have to save stuff for existing users who signed up before the switch to oauth2
				if not user.oauth
					user.name = googleUserMetadata.name
					if not user.picture and picture = googleUserMetadata.picture
						user.picture = picture
					user.oauth = accessTokenExtra.refresh_token
					user.save (err) ->
						throw err if err
						promise.fulfill user
				else if accessTokenExtra.refresh_token isnt user.oauth
					user.oauth = accessTokenExtra.refresh_token
					user.save (err) ->
						throw err if err
						promise.fulfill user
				else
					promise.fulfill user
				# END TEMPORARY ###########
			else
				user = new models.User
				user.email = email
				user.name = googleUserMetadata.name
				if picture = googleUserMetadata.picture
					user.picture = picture
				user.oauth = accessTokenExtra.refresh_token
				user.save (err) ->
					throw err if err
					promise.fulfill user
		promise = @Promise()
	addToSession: (session, auth) ->
		session.user = auth.user.id
	sendResponse: (res, data) ->
		user = data.user
		if not user.id
			return res.redirect '/invalid'
		if not user.lastParsed
			return res.redirect '/load'
		res.redirect "/profile"


app.configure ->
	app.set 'port', process.env.PORT or 5000

	app.set 'views', path.join(root, 'views')
	app.set 'view engine', 'jade'
	app.locals.pretty = process.env.NODE_ENV is 'development'

	app.use (req, res, next) ->
		if req.headers.host isnt process.env.HOST
			url = util.baseUrl + req.url
			res.writeHead 301, Location: url
			return res.end()
		next()
	# app.use express.logger('dev')
	# app.use express.profiler()
	app.use express.favicon(path.join(root, 'favicon.ico'))
	app.use express.compress()
	app.use express.static(path.join(root, 'public'))
	# app.use express.bodyParser()
	# app.use express.methodOverride()
	app.use express.cookieParser 'cat on a keyboard in space'
	app.use express.session(key: key, store: store)

	app.use passport.initialize()
	app.use passport.session()

	app.use everyauth.middleware()
	app.use (req, res, next) ->
		if user = process.env.AUTO_AUTH
			req.session.user = user
		next()
	app.use app.router
	app.use pipeline.middleware()
	app.use (req, res) ->
		res.render 'index'

app.configure 'development', ->
	app.use express.errorHandler()

app.configure 'production', ->
	app.use (err, req, res, next) ->
		console.error err
		res.statusCode = 500
		res.render 'error'

io = require('socket.io').listen server

# Heroku doesn't support websockets, force long polling.
io.set 'transports', ['xhr-polling']	# TODO remove this line if moving to ec2
io.set 'polling duration', 10
io.set 'log level', if process.env.NODE_ENV is 'development' then 2 else 1

io.set 'store', do ->
	SocketioRedisStore = require 'socket.io/lib/stores/redis'
	redis = require 'socket.io/node_modules/redis'
	clients = (redis.createClient(redisConfig.port, redisConfig.host) for i in [1..3])
	for client in clients
		client.auth redisConfig.pass, (err) ->
			throw err if err

	new SocketioRedisStore
		redis: redis
		redisPub: clients[0]
		redisSub: clients[1]
		redisClient: clients[2]


io.set 'authorization', (data, accept) ->
	if not data.headers.cookie
		return accept 'No cookie transmitted.', false
	cookie = require 'cookie'
	data.cookie = cookie.parse data.headers.cookie
	data.sessionId = data.cookie[key].substring 2, 26

	store.load data.sessionId, (err, session) ->
		throw err if err
		if not session
			return accept 'No session.', false

		data.session = session
		return accept null, true

io.sockets.on 'connection', (socket) ->
	require('./api') app, socket

	pipeline.on 'invalidate', ->
		socket.emit 'reloadStyles'

app.get '/app.js', do ->
	bundle = require('browserify')
		watch: process.env.NODE_ENV is 'development'
		# debug: true	# TODO see if this helps EITHER devtools debugging or better stacktrace reporting on prod. Remove if neither.
		exports: 'process'
	bundle.register '.jade', (body, file) ->
		result = null
		app.render file, (err, data) ->
			throw err if err
			data = data.replace(/(\r\n|\n|\r)/g, '').replace(/'/g, '&apos;')
			result = 'module.exports = Ember.Handlebars.compile(\'' + data + '\');'
		result
	bundle.addEntry 'lib/app/index.coffee'

	content = bundle.bundle()
	for variable in ['NODE_ENV', 'HOST']
		content = content.replace '[' + variable + ']', process.env[variable]
	# TODO Maybe remove (also uglify dependency) in favor of in-tact line numbers for clientside error reporting. Or only minify non-app code.
	if process.env.NODE_ENV is 'production'
		content = require('uglify-js').minify(content, fromString: true).code

	(req, res) ->
		res.set 'Content-Type', 'application/javascript'
		res.send content


server.listen app.get('port'), ->
	console.info 'App started in ' + process.env.APP_ENV + ' environment, listening on port ' + app.get('port')
