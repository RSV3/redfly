models = require 'phrenetic/lib/server/models'
validators = require('validator').validators
util = require './util'


Schema = models.db.Schema
Types = Schema.Types


oldexcludeSchema = new Schema
	email: type: String, trim: true, lowercase: true, validate: validators.isEmail
	name: type: String, trim: true

AdminSchema = new Schema
	_id: Number					# special case: there is only one admin record, so let's call it _id:1
	domains: [ type: String ]	# list of domains served by this instance
	blacklistdomains: [ type: String ]	# list of domains blacklisted from the service
	blacklistemails: [ type: String ]	# list of emails blacklisted from the service
	blacklistnames: [ type: String ]	# list of names blacklisted from the service
	userstoo: type: Boolean		# if set, employees (inc. users) can also be classified as contacts
	flushsave: type: Boolean	# if set, FLUSH saves queued contacts: otherwise, skips
	hidemails: type: Boolean		# hide the email of unknown contacts

ClassifySchema = new Schema
	user: type: Types.ObjectId, ref: 'User'
	contact: type: Types.ObjectId, ref: 'Contact', required: true
	saved: type: Date

ExcludeSchema = new Schema
	user: type: Types.ObjectId, ref: 'User'
	contact: type: Types.ObjectId, ref: 'Contact'

UserSchema = new Schema
	email: type: String, required: true, unique: true, trim: true, lowercase: true, validate: validators.isEmail
	name: type: String, required: true, trim: true
	picture: type: String, trim: true, validate: validators.isUrl
	oauth: type: String	# This would be required, but it might briefly be empty during the OAuth2 migration.
	lastParsed: type: Date
	# queue: [ type: Types.ObjectId, ref: 'Contact' ]		# now built dynamicly from mails, classifies, excludes
	# excludes: [oldexcludeSchema]		# now mapped in excludes
	admin: type: Boolean
	linkedin: type: String
	linkedInAuth: 
		token: type: String
		secret: type: String
	cIO:
		salt: type: String
		hash: type: String
		label: type: String
		user: type: String		# TODO: store and search on this where appropriate
		host: type: String		# TODO: store if default override
		port: type: Number		# TODO: store if default override
		ssl: type: Boolean		# TODO: store if default override
		expired: type: Boolean		# TODO: if the password fails in nudge, set this and ask user to provide a new one


MeasurementSchema = new Schema
	user: type: Types.ObjectId, ref: 'User'
	contact: type: Types.ObjectId, ref: 'Contact'
	attribute: type: String
	value: type: Number

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
	isVip: type: Boolean
	linkedin: type: String, trim: true, match: util.socialPatterns.linkedin
	twitter: type: String, trim: true, match: util.socialPatterns.twitter
	facebook: type: String, trim: true, match: util.socialPatterns.facebook

TagSchema = new Schema
	creator: type: Types.ObjectId, ref: 'User'#, required: true
	contact: type: Types.ObjectId, ref: 'Contact'#, required: true
	category: type: String, required: true, enum: ['role', 'theme', 'project', 'organisation', 'industry']
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
	pictureUrl: type: String, trim: true
	yearsExperience: type: Number
	lastLink: type: Date


MergeSchema = new Schema
	contacts: [Types.Mixed]


chatSchema = new Schema
	handle: type: String
	client: type: String

photoSchema = new Schema
	typeId: type: String
	typeName: type: String
	url: type: String
	isPrimary: type: Boolean

socialProfileSchema = new Schema
	typeId: type: String
	typeName: type: String
	id: type: String
	username: type: String
	url: type: String
	bio: type: String
	rss: type: String
	following: type: String
	followers: type: String

footprintTopicSchema = new Schema
	value: type: String
	provider: type: String

footprintScoreSchema = new Schema
	value: type: Number
	provider: type: String
	type: type: String

organizationSchema = new Schema
	title: type: String
	name: type: String
	startDate: type: String
	isPrimary: type: Boolean

enhancedSchema = new Schema
	isPrimary: type: Boolean
	url: type: String

FullContactSchema = new Schema
	contact: type: Types.ObjectId, ref: 'Contact'
	contactInfo:
		familyName: type: String
		givenName: type: String
		fullName: type: String
	websites: [types: String]
	chats: [chatSchema]
	demographics:
		age: type: String
		locationGeneral: type: String
		gender: type: String
		ageRange: type: String
	photos: [photoSchema]
	socialProfiles: [socialProfileSchema]
	digitalFootprint:
		topics: [footprintTopicSchema]
		scores: [footprintScoreSchema]
	organizations: [organizationSchema]
	enhancedData: [enhancedSchema]

UserSchema.plugin models.common
ContactSchema.plugin models.common
TagSchema.plugin models.common
NoteSchema.plugin models.common
MailSchema.plugin models.common
LinkedInSchema.plugin models.common
MergeSchema.plugin models.common
ExcludeSchema.plugin models.common
FullContactSchema.plugin models.common
MeasurementSchema.plugin models.common

TagSchema.index {contact: 1, body: 1, category: 1}, unique: true

exports.Admin = models.db.model 'Admin', AdminSchema
exports.User = models.db.model 'User', UserSchema
exports.Contact = models.db.model 'Contact', ContactSchema
exports.Tag = models.db.model 'Tag', TagSchema
exports.Note = models.db.model 'Note', NoteSchema
exports.Mail = models.db.model 'Mail', MailSchema
exports.LinkedIn = models.db.model 'LinkedIn', LinkedInSchema
exports.Merge = models.db.model 'Merge', MergeSchema
exports.Exclude = models.db.model 'Exclude', ExcludeSchema
exports.Classify = models.db.model 'Classify', ClassifySchema
exports.FullContact = models.db.model 'FullContact', FullContactSchema
exports.Measurement = models.db.model 'Measurement', MeasurementSchema
exports.ObjectId = models.db.Types.ObjectId
exports.tmStmp = (id)->
	parseInt id.toString().slice(0,8), 16

