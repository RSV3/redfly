module.exports = (root, optimize) ->
	path = require 'path'
	convoy = require 'convoy'
	less = require 'less'


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
					options =
						filename: basePath
						paths: [path.dirname(basePath)]
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


	module.exports = pipeline.middleware()
