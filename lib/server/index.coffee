http = require 'http'
path = require 'path'
express = require 'express'
gzippo = require 'gzippo'
derby = require 'derby'
mongo = require 'racer-db-mongo'

# RedisStore = require('connect-redis')(express)

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

# TODO XXX delete these
model = store.createModel()
model.set 'contacts.178.name', 'John Resig'
model.set 'contacts.178.added_by', 'Kwan Lee'
model.set 'contacts.178.date', +new Date
model.push 'contacts.178.tags', 'Sweet Tag Bro'
model.push 'contacts.178.tags', 'VC'
model.push 'contacts.178.notes',
	date: +new Date
	text: 'Lorem ipsum dolor ist asdf asdfadf dasf adsf adsf adsf asdfads fads fads'
	author: 178
model.push 'contacts.178.notes',
	date: +new Date
	text: 'asdf ipsum dolor ist asdf asdfadf dasf adsf adsf adsf asdfads fads fads'
	author: 178
model.set 'users.178.email', 'kbaranowski@redstar.com'
model.set 'users.178.name', 'Krzysztof Baranowski'

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
	# 		req.session.user = 178
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



# Server-only routes go here.
# expressApp.all '*', (req) ->
# 	throw "404: #{req.url}"
