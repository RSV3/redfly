http = require 'http'
path = require 'path'
express = require 'express'
gzippo = require 'gzippo'
RedisStore = require('connect-redis')(express)

util = require './util'

require 'mongoose'	# Mongo driver borks if not loaded up before other stuff.



app = express()
server = http.createServer(app)

root = path.dirname path.dirname __dirname

key = 'express.sid'
store = new RedisStore do ->
	url = require('url').parse process.env.REDISTOGO_URL
	host: url.hostname
	port: url.port
	pass: url.auth.split(':')[1]


app.configure ->
	app.set 'port', process.env.PORT or 5000

	app.set 'views', root + '/views'
	app.set 'view engine', 'jade'
	app.locals.pretty = process.env.NODE_ENV is 'development'

	app.use (req, res, next) ->
		if req.headers.host isnt process.env.HOST
			url = req.protocol + process.env.HOST + req.url
			res.writeHead 301, Location: url
			return res.end()
		next()
	# app.use express.logger('dev')
	# app.use express.profiler()
	app.use express.favicon(root + '/favicon.ico')
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

	pipeline = require('./pipeline')(root, app)
	app.use pipeline.middleware()
	# app.use pipeline.catchall
	app.use (req, res) ->
		res.locals.root = path.basename root
		res.render 'index'

app.configure 'development', ->
	app.use express.errorHandler()

app.configure 'production', ->
	app.use (err, req, res, next) ->
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
		# throw new Error 'No session.' if not session    # TODO remove
		if not session
			return accept 'No session.', false

		data.session = session
		return accept null, true

io.sockets.on 'connection', (socket) ->
	require('./api')(app, socket)



server.listen app.get('port'), ->
	console.info 'Express server listening on port ' + app.get('port')
