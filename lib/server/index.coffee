http = require 'http'
path = require 'path'
express = require 'express'
gzippo = require 'gzippo'
RedisStore = require('connect-redis') express

util = require './util'

require 'mongoose'	# Mongo driver borks if not loaded up before other stuff.



app = express()
server = http.createServer app
root = path.dirname path.dirname __dirname
pipeline = require('./pipeline') root

key = 'express.sid'
store = new RedisStore do ->
	url = require('url').parse process.env.REDISTOGO_URL
	host: url.hostname
	port: url.port
	pass: url.auth.split(':')[1]


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
	# app.use gzippo.staticGzip(path.join(root, 'public'))	# TODO comment in when gzippo works
	app.use express.static(path.join(root, 'public'))	# TODO delete when gzippo works
	app.use express.compress()

	app.use express.bodyParser()
	app.use express.methodOverride()
	app.use express.cookieParser 'cat on a keyboard in space'
	app.use express.session(key: key, store: store)

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



app.get '/authorized', (req, res) ->
	data = req.session.authorizeData
	delete req.session.authorizeData

	# Authroize flow has temporarily been commandeered for login too.
	models = require './models'
	models.User.findOne email: data.email, (err, user) ->
		throw err if err
		if user
			req.session.user = user.id
			return res.redirect '/profile'
		else

			oauth = require 'oauth-gmail'
			client = oauth.createClient()
			client.getAccessToken data.request, req.query.oauth_verifier, (err, result) ->
				throw err if err

				# Create the user and log him in.
				models = require './models'
				user = new models.User
				user.email = data.email
				user.oauth =
					token: result.accessToken
					secret: result.accessTokenSecret
				user.save (err) ->
					throw err if err

					req.session.user = user.id
					res.redirect '/load'



io = require('socket.io').listen server

io.configure ->
	# Heroku doesn't support websockets, force long polling.
	io.set 'transports', ['xhr-polling']
	io.set 'polling duration', 10
	if process.env.NODE_ENV is 'production'
		io.set 'log level', 1

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



bundle = require('browserify')
	watch: process.env.NODE_ENV is 'development'
	debug: true	# TODO see if this helps EITHER devtools debugging or better stacktrace reporting on prod. Remove if neither.
	exports: 'process'
bundle.register '.jade', (body, file) ->
	result = null
	app.render file, (err, data) ->
		throw err if err
		data = data.replace(/(\r\n|\n|\r)/g, '').replace(/'/g, '&apos;')
		result = 'module.exports = Ember.Handlebars.compile(\'' + data + '\');'
	result
bundle.addEntry 'lib/app/index.coffee'

app.get '/app.js', (req, res) ->
	res.writeHead(200, {'Content-Type': 'application/javascript'})

	content = bundle.bundle()
	for variable in ['NODE_ENV', 'HOST']
		content = content.replace '[' + variable + ']', process.env[variable]
	res.end content



server.listen app.get('port'), ->
	console.info 'App started in ' + process.env.APP_ENV + ' environment, listening on port ' + app.get('port')
