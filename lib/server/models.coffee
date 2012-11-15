validators = require('validator').validators

db = require('./services').getDb()

Schema = db.Schema
Types = Schema.Types


excludeSchema = new Schema
	email: type: String, trim: 1, lowercase: 1, validator: validators.isEmail
	name: type: String, trim: 1

UserSchema = new Schema
	email: type: String, required: 1, unique: 1, trim: 1, lowercase: 1, validator: validators.isEmail
	name: type: String, trim: 1	# Would be required but the user's name isn't known at the time of signup.
	oauth:
		token: type: String, required: 1
		secret: type: String, required: 1
	lastParsed: type: Date
	queue: [ type: Types.ObjectId, ref: 'Contact' ]
	excludes: [excludeSchema]


ContactSchema = new Schema
	emails: [ type: String ]
	names: [ type: String ]
	picture: type: String, trim: 1, validator: validators.isUrl
	knows: [ type: Types.ObjectId, ref: 'User' ]
	added: type: Date
	addedBy: type: Types.ObjectId, ref: 'User'

TagSchema = new Schema
	creator: type: Types.ObjectId, ref: 'User', required: 1
	contact: type: Types.ObjectId, ref: 'Contact', required: 1
	category: type: String, required: 1, enum: ['redstar', 'industry']
	body: type: String, required: 1, trim: 1, lowercase: 1

NoteSchema = new Schema
	author: type: Types.ObjectId, ref: 'User', required: 1
	contact: type: Types.ObjectId, ref: 'Contact', required: 1
	body: type: String, required: 1, trim: 1

MailSchema = new Schema
	sender: type: Types.ObjectId, ref: 'User', required: 1
	recipient: type: Types.ObjectId, ref: 'Contact', required: 1
	subject: type: String
	sent: type: Date


common = (schema) ->
	schema.add
		date: type: Date, required: 1, default: Date.now
		
	schema.set 'toJSON', getters: true	# To make 'id' included in json serialization for the API.


excludeSchema.plugin common
UserSchema.plugin common

ContactSchema.plugin common
TagSchema.plugin common
NoteSchema.plugin common
MailSchema.plugin common


exports.User = db.model 'User', UserSchema
exports.Contact = db.model 'Contact', ContactSchema
exports.Tag = db.model 'Tag', TagSchema
exports.Note = db.model 'Note', NoteSchema
exports.Mail = db.model 'Mail', MailSchema
