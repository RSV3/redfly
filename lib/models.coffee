mongoose = require 'mongoose'
validators = require('validator').validators
_ = require 'underscore'

mongoose.connect process.env.MONGOLAB_URI

Schema = mongoose.Schema
Types = Schema.Types



UserSchema = new Schema
	date: type: Date, default: Date.now
	email: type: String, required: 1, unique: 1, trim: 1, lowercase: 1, validator: validators.isEmail
	name: type: String, required: 1, trim: 1
	oauth:
		token: type: String, required: 1
		secret: type: String, required: 1

ContactSchema = new Schema
	date: type: Date, default: Date.now
	email: type: String, required: 1, unique: 1, trim: 1, lowercase: 1, validator: validators.isEmail
	name: type: String, trim: 1
	_addedBy: type: Types.ObjectId, ref: 'User'
	dateAdded: type: Date
	_knows: [ type: Types.ObjectId, ref: 'User' ]
	tags: [ type: String, trim: 1 ]
	notes: [
		date: type: Date, default: Date.now
		# _author: Types.ObjectId, ref: 'User', required: 1	# TODO XXX what's the problem?
		body: type: String, required: 1, trim: 1
	]

MailSchema = new Schema
	date: type: Date, default: Date.now
	_sender: type: Types.ObjectId, ref: 'User', required: 1
	_recipient: type: Types.ObjectId, ref: 'Contact', required: 1
	subject: type: String
	dateSent: type: Date, required: 1


exports.User = mongoose.model 'User', UserSchema
exports.Contact = mongoose.model 'Contact', ContactSchema
exports.Mail = mongoose.model 'Mail', MailSchema
