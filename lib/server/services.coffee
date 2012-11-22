db = null
exports.getDb = ->
	if not db
		db = require 'mongoose'
		db.set 'debug', process.env.NODE_ENV is 'development'
		db.connect process.env.MONGOLAB_URI
	db

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
