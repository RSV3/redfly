mongoose = require 'mongoose'
validators = require('validator').validators

mongoose.connect process.env.MONGOLAB_URI

Schema = mongoose.Schema
Types = Schema.Types



UserSchema = new Schema
	date: type: Date, required: 1, default: Date.now
	email: type: String, required: 1, unique: 1, trim: 1, lowercase: 1, validator: validators.isEmail
	name: type: String, trim: 1	# TODO I'd like to make this required but the parsing process finds the user's name later. It's probably fine.
	oauth:
		token: type: String, required: 1
		secret: type: String, required: 1
	# TODO maybe make these below part of a 'meta' field
	dateParsedLast: type: Date
	classifyIndex: type: Number, required: 1, default: 0, min: 0
	classify: [ type: Types.ObjectId, ref: 'Contact' ]

ContactSchema = new Schema
	date: type: Date, required: 1, default: Date.now
	email: type: String, required: 1, unique: 1, trim: 1, lowercase: 1, validator: validators.isEmail
	name: type: String, required: 1, trim: 1
	addedBy: type: Types.ObjectId, ref: 'User'
	dateAdded: type: Date
	knows: [ type: Types.ObjectId, ref: 'User' ]

TagSchema = new Schema
	date: type: Date, required: 1, default: Date.now
	creator: type: Types.ObjectId, ref: 'User', required: 1
	contact: type: Types.ObjectId, ref: 'Contact', required: 1
	body: type: String, required: 1, trim: 1

NoteSchema = new Schema
	date: type: Date, required: 1, default: Date.now
	author: type: Types.ObjectId, ref: 'User', required: 1
	contact: type: Types.ObjectId, ref: 'Contact', required: 1
	body: type: String, required: 1, trim: 1

MailSchema = new Schema
	date: type: Date, required: 1, default: Date.now
	sender: type: Types.ObjectId, ref: 'User', required: 1
	recipient: type: Types.ObjectId, ref: 'Contact', required: 1
	subject: type: String
	dateSent: type: Date


exports.User = mongoose.model 'User', UserSchema
exports.Contact = mongoose.model 'Contact', ContactSchema
exports.Tag = mongoose.model 'Tag', TagSchema
exports.Note = mongoose.model 'Note', NoteSchema
exports.Mail = mongoose.model 'Mail', MailSchema
