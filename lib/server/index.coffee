path = require 'path'
express = require 'express.io'

util = require './util'


root = path.dirname path.dirname __dirname
app = express().http().io()
assets = require('./assets') root, app, ['NODE_ENV', 'HOST']
RedisStore = require('connect-redis') express
redisConfig = do ->
	url = require('url').parse process.env.REDISTOGO_URL
	host: url.hostname
	port: url.port
	pass: url.auth.split(':')[1]

require './auth'


app.configure ->
	app.set 'port', process.env.PORT or 5000

	app.set 'views', path.join(root, 'views')
	app.set 'view engine', 'jade'
	app.locals.pretty = true

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
	app.use express.cookieParser()
	app.use express.session(store: new RedisStore(redisConfig), secret: 'cat on a keyboard in space')
	app.use require('everyauth').middleware()
	app.use (req, res, next) ->
		if user = process.env.AUTO_AUTH
			req.session.user = user
		next()
	app.use app.router
	app.use assets.pipeline.middleware()
	app.use (req, res) ->
		res.render 'index'

app.configure 'development', ->
	app.use express.errorHandler()

app.configure 'production', ->
	app.use (err, req, res, next) ->
		console.error err
		res.statusCode = 500
		res.render 'error'


app.io.set 'transports', ['xhr-polling']	# TODO remove this line if moving to ec2
app.io.set 'polling duration', 10
app.io.set 'log level', if process.env.NODE_ENV is 'development' then 2 else 1

app.io.set 'store', do ->
	redis = require 'redis'
	clients = (redis.createClient(redisConfig.port, redisConfig.host) for i in [1..3])
	for client in clients
		client.auth redisConfig.pass, (err) ->
			throw err if err
	new express.io.RedisStore
		redis: redis
		redisPub: clients[0]
		redisSub: clients[1]
		redisClient: clients[2]

require('./routes') app
assets.bundle.on 'bundle', ->
	app.io.broadcast 'reloadApp'
assets.pipeline.on 'invalidate', ->
	app.io.broadcast 'reloadStyles'


app.listen app.get('port'), ->
	console.info 'App started in ' + process.env.APP_ENV + ' environment, listening on port ' + app.get('port')
