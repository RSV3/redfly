services = require './services'

util = module.exports = require '../util'


# Example mail options.
# options = 
# 	from: 'Sender Name <sender@example.com>'
# 	to: 'receiver1@example.com, receiver2@example.com'
# 	subject: 'Hello!'
# 	html: '<strong>Hello world.</strong>'
util.mail = (options, cb) ->
	if intercept = process.env.INTERCEPT_EMAIL
		options.replyTo = options.to
		options.to = intercept
	services.getTransport().sendMail options, (err, response) ->
		throw err if err	# TODO change this to logging/airbrake
		console.info 'Message sent: ' + response.message
		cb?()
