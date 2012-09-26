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
optimize = if process.env.OPTIMIZE then true else false

key = 'express.sid'
store = new RedisStore do ->
	parse = require('url').parse
	redisToGo = parse process.env.REDISTOGO_URL
	host: redisToGo.hostname
	port: redisToGo.port
	pass: redisToGo.auth.split(':')[1]


app.configure ->
	app.set 'port', process.env.PORT or 5000

	# Mail template rendering.
	app.set 'views', root + '/mail'
	app.set 'view engine', 'jade'
	app.locals.pretty = not optimize

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
	app.use express.session
		key: key
		store: store

	# TODO this is probably still useful! Just make the lookup smarkter, and change config-local
	# app.use (req, res, next) ->
	# 	if user = process.env.AUTO_AUTH
	# 		req.session.user = user
	# 	next()

	app.use app.router

	app.use require('./pipeline')(root, optimize)

	# TODO how do 404 etc (error) pages work with ember? If I do them
	# on the server then keep this, change view root to not be mail, change
	# mail functions appropriately, grab pages from poverup and consolidate
	app.use (req, res, next) ->
		next new util.NotFound
	app.use (err, req, res, next) ->
		if err instanceof util.NotFound
			res.send 404, 'Page not found'
			# res.statusCode = 404;
			# res.locals.title = 'Page Not Found :('
			# res.render 'error/not_found'
		else if err instanceof util.AccessDenied
			res.send 403, 'Access denied'
			# res.statusCode = 403
			# res.render 'error/access_denied'
		else
			next err

app.configure 'development', ->
	app.use express.errorHandler()

app.configure 'production', ->
	app.use (err, req, res, next) ->
		# TODO maybe send error email to myself here, or just check the logs. Consider attaching to 'uncaughtException' too.
		res.send 500, 'Error'
		# res.statusCode = 500
		# res.render 'error/error'



app.get '/authorized', (req, res) ->
	data = req.session.authorizeData
	delete req.session.authorizeData

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
			res.redirect('/#/load')	# TODO exposes url creation strategy



io = require('socket.io').listen server

# Heroku doesn't support websockets, force long polling.
io.configure ->
	io.set 'transports', ['xhr-polling']
	io.set 'polling duration', 10

io.set 'authorization', (data, accept) ->
	if not data.headers.cookie
		return accept 'No cookie transmitted.', false
	cookie = require 'cookie'
	data.cookie = cookie.parse data.headers.cookie
	data.sessionId = data.cookie[key].substring 2, 26

	store.load data.sessionId, (err, session) ->
		throw err if err
		throw new Error 'No session.' if not session	# TODO this can happen if page is idle for a while. Probably create a new session here.

		data.session = session
		return accept null, true

io.sockets.on 'connection', (socket) ->
	require('./api')(app, socket)



server.listen app.get('port'), ->
	console.info 'Express server listening on port ' + app.get('port')
