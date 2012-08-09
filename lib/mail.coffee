module.exports = (app) ->
	util = require './util'


	send = (template, options) ->
		locals =
			path: (url) ->
				'http://' + process.env.HOST + url

		app.render template, locals, (err, html) ->
			throw err if err

			options.html = html
			options.from ?= 'Krzysztof || Chris <kbaranowski@redstar.com>'
			util.mail options


	sendWelcome: (to) ->
		send 'welcome',
			to: to
			subject: 'Thank you for joining Redfly!'
