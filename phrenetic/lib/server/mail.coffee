module.exports = (projectRoot) ->

	# Example mail options.
	# options = 
	# 	from: 'Sender Name <sender@example.com>'
	# 	to: 'receiver1@example.com, receiver2@example.com'
	# 	subject: 'Hello!'
	# 	html: '<strong>Hello world.</strong>'
	send = (options, cb) ->
		if intercept = process.env.INTERCEPT_EMAIL
			options.replyTo = options.to
			options.to = intercept
		services = require './services'
		services.getTransport().sendMail options, (err, response) ->
			if err
				console.error err
				return cb? err
			console.info "Email sent to #{options.to} with response #{response.message}"
			cb?()

	sendTemplate = (template, options, cb) ->
		filename = "#{projectRoot}/mail/#{template}.jade"
		options.filename = filename
		options.cache = true
		options.path = (path) ->
			util = require './util'
			util.baseUrl + path
		require('fs').readFile filename, 'utf8', (err, str) ->
			throw err if err
			require('jade').render str, options, (err, html) ->
				throw err if err
				options.html = html
				send options, cb


	send: send
	sendTemplate: sendTemplate
