http = require 'http'
path = require 'path'
express = require 'express'
gzippo = require 'gzippo'
convoy = require 'convoy'
io = require 'socket.io'
RedisStore = require('connect-redis')(express)
_ = require 'underscore'

util = require '../util'



app = express()
server = http.createServer(app)

root = path.dirname path.dirname __dirname
optimize = if process.env.OPTIMIZE then true else false

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
			base = root + '/styles/base.less'
			fs = require 'fs'
			fs.readFile base, 'utf8', (err, body) ->
				return done(err) if err
				less = require 'less'
				options = {}
				options.filename = base
				new less.Parser(options).parse body, (err, tree) ->
					return done(err) if err
					assset.body = tree.toCSS(compress: optimize) + '\n' + asset.body	# 'compress' option won't be necessary once Convoy minifies css
					done()
		]
		minify: optimize	# Convoy doesn't minify css yet.
		autocache: not optimize
	# TODO XXX copy? is anyhting requesting at index.html? What if the app comes from other routes? HOW DOES ROUTING WORK
	'index.html':
		root: root + '/views'
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



# TODO XXX all this login logout stuff. Maybe move it to another file too, like in poverup
# login = (req, id, res) ->
# 	req.getModel().session.user = id
# 	# TODO session/cookie hack, get rid of 'res' param
# 	res.cookie 'user', id

# logout = (req) ->
# 	delete req.getModel().session.user # TODO XXX try logging out
# 	# req.getModel().session.destroy()	# TODO see if destorying the session is okay (derby puts some stuff there), or if this even works. Try conssole.dir req.getModel().session and see if there's a destroy method.

# app.post '/login', (req, res) ->
# 	# If the user has never logged in before, redirect to gmail oauth page. Otherwise, log in.
# 	model = req.getModel()
# 	email = req.body.email
# 	model.fetch model.query('users').findByEmail(email), (err, userModel) ->
# 		throw err if err
# 		user = userModel.get()
# 		# TODO do authentication, either openID or: if user and user.password is req.body.password
# 		if user
# 			login req, user.id, res
# 			res.send()
# 		else
# 			oauth = require 'oauth-gmail'
# 			client = oauth.createClient callbackUrl: 'http://' + process.env.HOST + '/authorized'
# 			client.getRequestToken email, (err, result) ->  # TODO XXX try mistyping an email and see what happens
# 				throw err if err
# 				model.session.authorizeData = email: email, request: result
# 				res.send result.authorizeUrl

# app.get '/logout', (req, res) ->
# 	logout req
# 	res.redirect '/'

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



io = require('socket.io').listen server

# Heroku doesn't support websockets, force long polling.
io.configure ->
	io.set 'transports', ['xhr-polling']
	io.set 'polling duration', 10


server.listen app.get('port'), ->
	console.info 'Express server listening on port ' + app.get('port')
