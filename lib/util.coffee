class exports.NotFound extends Error
	constructor: (msg) ->
		super msg

class exports.AccessDenied extends Error
	constructor: (msg) ->
		super msg



mailer = require 'nodemailer'

transport = mailer.createTransport 'SMTP',
	service: 'SendGrid'
	auth:
		user: process.env.SENDGRID_USERNAME
		pass: process.env.SENDGRID_PASSWORD

# Example mail options.
# options = 
# 	from: 'Sender Name <sender@example.com>'
# 	to: 'receiver1@example.com, receiver2@example.com'
# 	subject: 'Hello!'
# 	html: '<strong>Hello world.</strong>'
exports.mail = (options) ->
	if process.env.INTERCEPT_EMAIL
		options.to = process.env.INTERCEPT_EMAIL
	transport.sendMail options, (err, response) ->
		if err
			# TODO change this to logging/airbrake
			throw err 
		else
			console.info 'Message sent: ' + response.message
