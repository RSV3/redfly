module.exports = (root, app) ->
	path = require 'path'
	convoy = require 'convoy'
	less = require 'less'


	pipeline = convoy
		watch: process.env.DEBUG

		'app.js':
			main: root + '/lib/app'
			packager: 'javascript'
			compilers:
				'.jade':
					(asset, context, done) ->
						app.render asset.path, (err, data) ->
							throw err if err
							data = data.replace(/(\r\n|\n|\r)/g, '')
							asset.body = 'module.exports = Ember.Handlebars.compile(\'' + data + '\');'
							done()
				'.js':  convoy.plugins.JavaScriptCompiler
				'.coffee': convoy.plugins.CoffeeScriptCompiler
			minify: not process.env.DEBUG
			autocache: process.env.DEBUG

		'app.css':
			main: root + '/styles'
			packager: require 'convoy-stylus'
			postprocessors: [ (asset, context, done) ->
				basePath = root + '/styles/base.less'
				fs = require 'fs'
				fs.readFile basePath, 'utf8', (err, body) ->
					return done err if err
					options =
						filename: basePath
						paths: [path.dirname(basePath)]
					new less.Parser(options).parse body, (err, tree) ->
						return done(err) if err
						asset.body = tree.toCSS(compress: not process.env.DEBUG) + '\n' + asset.body	# 'compress' option won't be necessary once Convoy minifies css
						done()
			]
			# minify: not process.env.DEBUG	# Doesn't do anything, convoy doesn't minify css yet.
			autocache: process.env.DEBUG

		'index.html':
			root: root + '/views/index.html'
			packager: 'copy'
			autocache: process.env.DEBUG

		'app.manifest':
			packager: require 'html5-manifest/packager'


	module.exports = pipeline.middleware()
