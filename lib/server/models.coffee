validators = require('validator').validators

db = require('./services').getDb()
util = require './util'

Schema = db.Schema
Types = Schema.Types


excludeSchema = new Schema
	email: type: String, trim: true, lowercase: true, validate: validators.isEmail
	name: type: String, trim: true

UserSchema = new Schema
	email: type: String, required: true, unique: true, trim: true, lowercase: true, validate: validators.isEmail
	name: type: String, required: true, trim: true
	picture: type: String, trim: true, validate: validators.isUrl
	oauth: type: String	# This would be required, but it might briefly be empty during the OAuth2 migration.
	lastParsed: type: Date
	queue: [ type: Types.ObjectId, ref: 'Contact' ]
	excludes: [excludeSchema]
	linkedin: type: String


ContactSchema = new Schema
	emails: [ type: String ]
	names: [ type: String ]
	picture: type: String, trim: true, validate: validators.isUrl
	knows: [ type: Types.ObjectId, ref: 'User' ]
	added: type: Date
	addedBy: type: Types.ObjectId, ref: 'User'
	position: type: String, trim: true
	company: type: String, trim: true
	yearsExperience: type: Number
	linkedin: type: String, trim: true, match: util.socialPatterns.linkedin
	twitter: type: String, trim: true, match: util.socialPatterns.twitter
	facebook: type: String, trim: true, match: util.socialPatterns.facebook

TagSchema = new Schema
	creator: type: Types.ObjectId, ref: 'User', required: true
	contact: type: Types.ObjectId, ref: 'Contact', required: true
	category: type: String, required: true, enum: ['redstar', 'industry']
	body: type: String, required: true, trim: true, lowercase: true

NoteSchema = new Schema
	author: type: Types.ObjectId, ref: 'User', required: true
	contact: type: Types.ObjectId, ref: 'Contact', required: true
	body: type: String, required: true, trim: true

MailSchema = new Schema
	sender: type: Types.ObjectId, ref: 'User', required: true
	recipient: type: Types.ObjectId, ref: 'Contact', required: true
	subject: type: String, trim: true
	sent: type: Date

LinkedInSchema = new Schema
	user: type: Types.ObjectId, ref: 'User'
	contact: type: Types.ObjectId, ref: 'Contact'
	linkedinId: type: String, required: true, unique: true
	name:
		firstName: type: String
		lastName: type: String
		formattedName: type: String
	positions: [ type: String ]
	companies: [ type: String ]
	industries: [ type: String ]
	specialties: [ type: String ]
	summary: type: String, trim: true
	headline: type: String, trim: true
	lastLink: type: Date


MergeSchema = new Schema
	contacts: [Types.Mixed]



common = (schema) ->
	schema.add
		date: type: Date, required: true, default: Date.now
	schema.set 'toJSON', getters: true	# To make 'id' included in json serialization for the API.


excludeSchema.plugin common
UserSchema.plugin common

ContactSchema.plugin common
TagSchema.plugin common
NoteSchema.plugin common
MailSchema.plugin common
LinkedInSchema.plugin common

MergeSchema.plugin common


TagSchema.index {contact: 1, body: 1, category: 1}, unique: true


exports.User = db.model 'User', UserSchema
exports.Contact = db.model 'Contact', ContactSchema
exports.Tag = db.model 'Tag', TagSchema
exports.Note = db.model 'Note', NoteSchema
exports.Mail = db.model 'Mail', MailSchema

exports.Merge = db.model 'Merge', MergeSchema
exports.LinkedIn = db.model 'LinkedIn', LinkedInSchema
