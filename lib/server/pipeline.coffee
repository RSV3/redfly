module.exports = (root) ->
	path = require 'path'
	convoy = require 'convoy'
	less = require 'less'


	convoy
		watch: process.env.NODE_ENV is 'development'

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
						return done err if err
						asset.body = tree.toCSS() + '\n' + asset.body
						done()
			]
			minify: process.env.NODE_ENV is 'production'
			autocache: process.env.NODE_ENV is 'development'
