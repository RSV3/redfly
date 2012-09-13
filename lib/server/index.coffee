http = require 'http'
path = require 'path'
express = require 'express'
gzippo = require 'gzippo'
convoy = require 'convoy'
less = require 'less'
RedisStore = require('connect-redis')(express)
_ = require 'underscore'

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




models = require '../models'


io.sockets.on 'connection', (socket) ->
	socket.on 'login', (email, fn) ->
		# If the user has never logged in before, redirect to gmail oauth page. Otherwise, log in.
		models.User.findOne email: email, (err, user) ->
			throw err if err

			# TODO do authentication, either openID or: if user and user.password is req.body.password
			if user
				login user.id, socket
				return fn()
			else

				# TODO XXX testing
				user = new models.User
				user.email = 'bobface13@asdf.com'
				user.name = 'bob bobson'
				user.oauth =
					token: 'asdf'
					secret: 'asdf'
				user.save (err) ->
					throw err if err
					login user.id, socket
					return fn()

				# oauth = require 'oauth-gmail'
				# client = oauth.createClient callbackUrl: 'http://' + process.env.HOST + '/authorized'
				# client.getRequestToken email, (err, result) ->  # TODO XXX try mistyping an email and see what happens
				# 	throw err if err
				# 	# model.session.authorizeData = email: email, request: result	# TODO XXX XXX how to save to session
				# 	return fn result.authorizeUrl
	socket.on 'logout', (fn) ->
		logout socket
		return fn()

	socket.on 'db', (data, fn) ->
		model = models[data.type]
		op = data.op
		if op is 'find'
			if id = data.id
				model.findById id, (err, doc) ->
					throw err if err
					return fn doc
			else if ids = data.ids
				model.find '_id': $in: ids, (err, docs) ->
					throw err if err
					return fn docs
			else if query = data.query
				model.find query, (err, docs) ->
					throw err if err
					return fn docs
			else
				model.find (err, docs) ->
					throw err if err
					return fn docs
		else if op is 'create'
			model.create data.details, (err, docs...) ->
				throw err if err
				return if docs.length is 1 then fn docs.get(0) else fn docs
		else if op is 'save'
			# TODO use model.save() to get validators and middleware
			throw new Error 'unimplemented'
		else if op is 'delete'
			if id = data.id
				model.findByIdAndRemove id, (err) ->
					throw err if err
					return fn()
			else if ids = data.ids
				# TODO Remove each one and call return fn() when they're ALL done
				throw new Error 'unimplemented'
			else
				throw new Error
		else
			throw new Error


pipeline = convoy
	watch: true

	'app.js':
		main: root + '/lib/app'
		packager: 'javascript'
		compilers:
			'.hbr': require('ember/packager').HandlebarsCompiler
			'.js':  convoy.plugins.JavaScriptCompiler
			'.coffee': convoy.plugins.CoffeeScriptCompiler
		minify: optimize
		autocache: not optimize
	'app.css':
		main: root + '/styles'
		packager: require 'convoy-stylus'
		postprocessors: [ (asset, context, done) ->
			basePath = root + '/styles/base.less'
			fs = require 'fs'
			fs.readFile basePath, 'utf8', (err, body) ->
				return done err if err
				options = {}
				options.filename = basePath
				options.paths = [path.dirname(basePath)]
				new less.Parser(options).parse body, (err, tree) ->
					return done(err) if err
					asset.body = tree.toCSS(compress: optimize) + '\n' + asset.body	# 'compress' option won't be necessary once Convoy minifies css
					done()
		]
		minify: optimize	# Convoy doesn't minify css yet.
		autocache: not optimize
	'index.html':
		root: root + '/views/index.html'
		packager: 'copy'
		autocache: not optimize
	'app.manifest':
		packager: require 'html5-manifest/packager'


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
	app.use pipeline.middleware()

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
