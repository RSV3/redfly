module.exports = (projectRoot) ->
	path = require 'path'
	
	url = require('url').parse process.env.REDISTOGO_URL

	root = path.dirname path.dirname __dirname
	express = require 'express'
	app = express()
	RedisStore = require('connect-redis') express
	redisConfig =
		host: url.hostname
		port: url.port
		pass: url.auth?.split(':')[1]

	app.configure ->
		app.set 'port', process.env.PORT or 5000

		app.set 'views', path.join(projectRoot, 'views')
		app.set 'view engine', 'jade'
		app.locals.pretty = true

		app.use (req, res, next) ->
			if req.headers.host isnt process.env.HOST
				util = require './util'
				url = util.baseUrl req.url
				res.writeHead 301, Location: url
				return res.end()
			next()

		# app.use express.logger('dev')
		# app.use express.profiler()
		app.use express.favicon(path.join(projectRoot, 'favicon.ico'))
		app.use express.compress()
		app.use express.static(path.join(root, 'public'))
		app.use express.static(path.join(projectRoot, 'public'))

		app.use express.json()			# for post body parsing
		app.use express.urlencoded()

		clandestine = 'cat on a keyboard in space'
		app.use express.cookieParser clandestine
		app.use express.session
			store: new RedisStore redisConfig
			secret: clandestine

		app.use (req, res, next) ->
			if user = process.env.AUTO_AUTH
				req.session.user = user
				req.session.save()
			next()
		
		# Hook for project-specific middleware.
		try
			require(projectRoot + '/lib/server/middleware') app
		catch

		assets = require('./assets') root, projectRoot, app, ['NODE_ENV', 'HOST']
		app.use assets.pipeline.middleware()
		app.use (req, res, next) ->		# default to render the page
			if req.xhr then return next()
			res.render 'main'
		require('./routes') projectRoot, app

	app.configure 'development', ->
		app.use express.errorHandler()

	app.configure 'production', ->
		app.use (err, req, res, next) ->
			console.error err
			res.statusCode = 500
			res.render 'error'


	# Heroku doesn't support websockets, force long polling.
	app.set 'log', true
	app.set 'log level', if process.env.NODE_ENV is 'development' then 2 else 1
	app.set 'store', do ->
		redis = require 'connect-redis/node_modules/redis'
		clients = (redis.createClient(redisConfig.port, redisConfig.host) for i in [1..3])
		for client in clients
			client.auth redisConfig.pass, (err) ->
				throw err if err
		new RedisStore
			redis: redis
			redisPub: clients[0]
			redisSub: clients[1]
			redisClient: clients[2]

	###
	assets.bundle.on 'bundle', ->
		app.broadcast 'reloadApp'
	assets.pipeline.on 'invalidate', ->
		app.io.broadcast 'reloadStyles'
	###

	app.listen app.get('port'), ->
		console.info 'App started in ' + process.env.APP_ENV + ' environment, listening on port ' + app.get('port')
