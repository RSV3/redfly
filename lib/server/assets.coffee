module.exports = (root, app, variables) ->
	path = require 'path'


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

	app.get '/app.js', do ->
		processCode = ->
			content = bundle.bundle()
			for variable in variables
				content = content.replace '[' + variable + ']', process.env[variable]
			# TODO Maybe remove (also uglify dependency) in favor of in-tact line numbers for clientside error reporting. Or only minify non-app code.
			if process.env.NODE_ENV is 'production'
				content = require('uglify-js').minify(content, fromString: true).code
			content
		code = processCode()
		bundle.on 'bundle', ->
			code = processCode()
		(req, res) ->
			res.header 'Content-Type', 'application/javascript'
			res.send code

	pipeline = require('convoy')
		watch: process.env.NODE_ENV is 'development'
		'app.css':
			main: root + '/styles'
			packager: require 'convoy-stylus'
			postprocessors: [ (asset, context, done) ->
				basePath = root + '/styles/base.less'
				fs = require 'fs'
				fs.readFile basePath, 'utf8', (err, body) ->
					return done err if err
					less = require 'less'
					options =
						filename: basePath
						paths: [path.dirname(basePath)]
					new less.Parser(options).parse body, (err, tree) ->
						return done err if err
						asset.body = tree.toCSS() + '\n' + asset.body
						done()
			]
			minify: process.env.NODE_ENV is 'production'
			autocache: process.env.NODE_ENV is 'development'


	bundle: bundle
	pipeline: pipeline