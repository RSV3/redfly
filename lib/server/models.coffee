validators = require('validator').validators

db = require('./services').getDb()

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
	linkedin: type: String
	queue: [ type: Types.ObjectId, ref: 'Contact' ]
	excludes: [excludeSchema]


ContactSchema = new Schema
	emails: [ type: String ]
	names: [ type: String ]
	picture: type: String, trim: true, validate: validators.isUrl
	position: type: String
	company: type: String
	knows: [ type: Types.ObjectId, ref: 'User' ]
	linkedin: type: String
	twitter: type: String
	facebook: type: String
	yearsXperience: type: Number
	added: type: Date
	addedBy: type: Types.ObjectId, ref: 'User'

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
	subject: type: String
	sent: type: Date


MergeSchema = new Schema
	contacts: [Types.Mixed]


LinkedInSchema = new Schema
	name:
		firstName: type: String
		lastName: type: String
		formattedName: type: String
	positions: [ type: String ]
	companies: [ type: String ]
	industries: [ type: String ]
	specialties: [ type: String ]
	contact: type: Types.ObjectId, ref: 'Contact'
	user: type: Types.ObjectId, ref: 'User'
	linkedinid: type: String
	summary: type: String
	headline: type: String



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
MergeSchema.plugin common
LinkedInSchema.plugin common

LinkedInSchema.index {contact:1}
LinkedInSchema.index {linkedinid:1}
TagSchema.index {contact: 1, body: 1, category: 1}, unique: true


exports.User = db.model 'User', UserSchema
exports.Contact = db.model 'Contact', ContactSchema
exports.Tag = db.model 'Tag', TagSchema
exports.Note = db.model 'Note', NoteSchema
exports.Mail = db.model 'Mail', MailSchema

exports.Merge = db.model 'Merge', MergeSchema
exports.LinkedIn = db.model 'LinkedIn', LinkedInSchema
