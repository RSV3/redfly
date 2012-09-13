http = require 'http'
path = require 'path'
express = require 'express'
gzippo = require 'gzippo'
RedisStore = require('connect-redis')(express)

util = require '../util'



app = express()
server = http.createServer(app)

root = path.dirname path.dirname __dirname
optimize = if process.env.OPTIMIZE then true else false




# TODO all this login logout stuff maybe move it to another file too, like in poverup
login = (id, socket) ->
	socket.set 'user', id
	socket.emit 'login', id
	# req.session.user = id # Won't work because no req, and a response cycle has to be completing

logout = (socket) ->
	socket.set 'user', null
	socket.emit 'logout'
	# req.session.destroy()	# Won't work because no req, and a response cycle has to be completing







io = require('socket.io').listen server

# Heroku doesn't support websockets, force long polling.
io.configure ->
	io.set 'transports', ['xhr-polling']
	io.set 'polling duration', 10






require('./services')(io, login, logout)




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
	app.use express.static(path.join(root, 'public'))	# TODO XXX delete when gzippo works
	app.use express.compress()
	app.use require('./pipeline')(root, optimize)

	app.use express.bodyParser()
	app.use express.methodOverride()

	app.use express.cookieParser('cat on a keyboard in space')
	app.use express.session store: new RedisStore do ->
		parse = require('url').parse
		redisToGo = parse process.env.REDISTOGO_URL
		host: redisToGo.hostname
		port: redisToGo.port
		pass: redisToGo.auth.split(':')[1]

	app.use (req, res, next) ->
		if autoUser = process.env.AUTO_AUTH
			req.session.user = autoUser
		next()

	app.use app.router

	# TODO XXX how do 404 etc (error) pages work with ember? If I do them
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



# TODO XXX
# app.get '/authorized', (req, res) ->
# 	model = req.getModel()
# 	data = model.session.authorizeData
# 	delete model.session.authorizeData

# 	oauth = require 'oauth-gmail'
# 	client = oauth.createClient()
# 	client.getAccessToken data.request, req.query.oauth_verifier, (err, result) ->
# 		throw err if err

# 		# Create the user and log him in.
# 		id = model.id()
# 		user =
# 			id: id
# 			date: +new Date
# 			email: data.email
# 			oauth:
# 				token: result.accessToken
# 				secret: result.accessTokenSecret
# 		model.set 'users.' + id, user
# 		login req, id, res

# 		res.redirect('/profile?signup=true')



server.listen app.get('port'), ->
	console.info 'Express server listening on port ' + app.get('port')
