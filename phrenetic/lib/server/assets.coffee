module.exports = (root, projectRoot, app, variables) ->
	path = require 'path'

	bundle = require('watchify')()
	bundle.transform 'coffeeify'

	through = require 'watchify/node_modules/browserify/node_modules/through'

	bundle.transform (filename) ->
		_s = require 'underscore.string'
		if not _s.endsWith(filename, 'lib/app/index.coffee') then return through()
		data = ''
		write = (buffer) ->
			data += buffer
		end = ->
			_ = require 'underscore'
			config = _.reduce variables, (memo, variable) ->
				memo + 'process.env.' + variable + ' = \'' + process.env[variable] + '\'\n'
			, ''
			data = data.replace 'CONFIG_VARIABLES', config
			@queue data
			@queue null
		through write, end

	bundle.transform (filename) ->
		extension = require('path').extname filename
		if extension isnt '.jade' then return through()
		data = ''
		write = (buffer) ->
			data += buffer
		end = ->
			try
				include = 'include ' + path.relative(path.dirname(filename), path.join(root, 'views/handlebars.jade')) + '\n'
				data = require('jade').compile(include + data, filename: filename)()
				data = data.replace /(action|bindAttr)="(.*?)"/g, (all, name, args) ->
					'{{' + name + ' ' + args.replace(/&quot;/g, '"') + '}}'
				data = data.replace(/'/g, '&apos;')
				data = data.replace(/(\r\n|\n|\r)/g, '').replace(/'/g, '&apos;')
				data = 'module.exports = Ember.Handlebars.compile(\'' + data + '\');'
			catch err
				@emit 'error', err
			@queue data
			@queue null
		through write, end
	bundle.require './lib/vendor/index.coffee', expose: 'vendor'
	bundle.add './lib/app/index.coffee'


	###
		exports: 'process'
		watch: process.env.NODE_ENV is 'development'
		# debug: true
	###
	###
	bundle.register 'post', (body) ->
		if process.env.NODE_ENV isnt 'production' then return body		# maybe should test for NODE_ENV is 'development'
		require('uglify-js').minify(body, fromString: true).code
	bundle.register '.jade', (body, filename) ->
		include = 'include ' + path.relative(path.dirname(filename), path.join(root, 'views/handlebars')) + '\n'
		data = require('jade').compile(include + body, filename: filename)()
		data = data.replace /(action|bindAttr)="(.*?)"/g, (all, name, args) -> '{{' + name + ' ' + args.replace(/&quot;/g, '"') + '}}'
		data = data.replace(/(\r\n|\n|\r)/g, '').replace(/'/g, '&apos;')
		'module.exports = Ember.Handlebars.compile(\'' + data + '\');'
	bundle.register (body) ->
		_ = require 'underscore'
		config = _.reduce variables, (memo, variable) ->
			memo + 'process.env.' + variable + ' = \'' + process.env[variable] + '\';\n'
		, ''
		body.replace 'CONFIG_VARIABLES', config
	bundle.on 'syntaxError', (err) ->
		throw new Error err
	bundle.addEntry 'lib/app/index.coffee'
	###

	code = null
	doBundle = (cb)->
		bundle.bundle (err, result) ->
			throw err if err
			code = if process.env.NODE_ENV is 'development' then result else require('uglify-js').minify(result, fromString: true, compress: false).code
			cb? code
	bundle.on 'bundle', ->
		doBundle()
	app.get '/app.js', (req, res) ->
		doBundle (bundledCode)->
			res.header 'Content-Type', 'application/javascript'
			res.send bundledCode

	pipeline = require('convoy') do ->
		createConfig = (name) ->
			main: projectRoot + '/styles/' + name
			packager: require 'convoy-stylus'
			postprocessors: [ (asset, context, done) ->
				basePath = projectRoot + '/styles/' + name + 'Base.less'
				context.watchPath basePath
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

		watch: process.env.NODE_ENV is 'development'
		'site.css': createConfig('site')
		'admin.css': createConfig('admin')
			


	bundle: bundle
	pipeline: pipeline
