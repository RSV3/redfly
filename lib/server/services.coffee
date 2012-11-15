db = null
exports.getDb = ->
	db ?= require('mongoose').connect process.env.MONGOLAB_URI

transport = null
exports.getTransport = ->
	transport ?= require('nodemailer').createTransport 'SMTP',
		service: 'SendGrid'
		auth:
			user: process.env.SENDGRID_USERNAME
			pass: process.env.SENDGRID_PASSWORD

exports.close = ->
	db?.disconnect()
	transport?.close()
