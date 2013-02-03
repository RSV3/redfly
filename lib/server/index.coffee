path = require 'path'
express = require 'express.io'

util = require './util'


app = express().http().io()
io = app.io
root = path.dirname path.dirname __dirname
pipeline = require('./pipeline') root

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
	app.use express.session(secret: 'cat on a keyboard in space')
	app.use require('everyauth').middleware()
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


bundle = require('browserify')
	watch: process.env.NODE_ENV is 'development'
	# debug: true	# TODO see if this helps EITHER devtools debugging or better stacktrace reporting on prod. Remove if neither.
	exports: 'process'
bundle.register '.jade', (body, filename) ->
	include = 'include ' + path.relative(path.dirname(filename), path.join(root, 'views/handlebars')) + '\n'
	data = require('jade').compile(include + body, filename: filename)()
	data = data.replace /(action|bindAttr)="(.*?)"/g, (all, name, args) -> '{{' + name + ' ' + args.replace(/&quot;/g, '"') + '}}'
	data = data.replace(/(\r\n|\n|\r)/g, '').replace(/'/g, '&apos;')
	'module.exports = Ember.Handlebars.compile(\'' + data + '\');'
bundle.addEntry 'lib/app/index.coffee'
bundle.on 'syntaxError', (err) ->
	throw new Error err


# Heroku doesn't support websockets, force long polling.
io.set 'transports', ['xhr-polling']	# TODO remove this line if moving to ec2
io.set 'polling duration', 10
io.set 'log level', if process.env.NODE_ENV is 'development' then 2 else 1

io.set 'store', do ->
	redis = require 'redis'
	config = do ->
		url = require('url').parse process.env.REDISTOGO_URL
		host: url.hostname
		port: url.port
		pass: url.auth.split(':')[1]
	clients = (redis.createClient(config.port, config.host) for i in [1..3])
	for client in clients
		client.auth config.pass, (err) ->
			throw err if err
	new express.io.RedisStore
		redis: redis
		redisPub: clients[0]
		redisSub: clients[1]
		redisClient: clients[2]

require('./routes') app
bundle.on 'bundle', ->
	io.broadcast 'reloadApp'
pipeline.on 'invalidate', ->
	io.broadcast 'reloadStyles'


app.get '/app.js', do ->
	processCode = ->
		content = bundle.bundle()
		for variable in ['NODE_ENV', 'HOST']
			content = content.replace '[' + variable + ']', process.env[variable]
		# TODO Maybe remove (also uglify dependency) in favor of in-tact line numbers for clientside error reporting. Or only minify non-app code.
		if process.env.NODE_ENV is 'production'
			content = require('uglify-js').minify(content, fromString: true).code
		content

	code = processCode()
	bundle.on 'bundle', ->
		code = processCode()
	(req, res) ->
		res.set 'content-Type', 'application/javascript'
		res.send code


app.listen app.get('port'), ->
	console.info 'App started in ' + process.env.APP_ENV + ' environment, listening on port ' + app.get('port')
