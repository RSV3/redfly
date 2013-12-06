schemasUtil = require 'phrenetic/lib/schemas'
validators = require('validator').validators

util = require './util'

Schema = schemasUtil.Schema
Types = schemasUtil.Types

schemas = []

schemas.push Schema 'Admin',
	_id: type: Number			# special case: there is only one admin record, so let's call it _id:1
	domains: [ type: String ]	# list of domains served by this instance
	authdomains: [ type: String ]	# list of domains users can auth with, in addition to domains
	whitelistemails: [ type: String ]	# list of emails that can log auth in addition to domains, authdomains
	blacklistdomains: [ type: String ]	# list of domains blacklisted from the service
	blacklistemails: [ type: String ]	# list of emails blacklisted from the service
	blacklistnames: [ type: String ]	# list of names blacklisted from the service
	userstoo: type: Boolean		# if set, employees (inc. users) can also be classified as contacts
	flushsave: type: Boolean	# if set, FLUSH saves queued contacts: otherwise, skips
	hidemails: type: Boolean	# hide the email of unknown contacts
	anyedit: type: Boolean		# allow any user to edit some contact fields
	orgtagcats: type: String	# comma delimited category names
	searchCnt: type: Number		# counts unique searches today
	searchCounts: [ type: Number ]		# stores last week of search counts

schemas.push Schema 'Classify',
	user: type: Types.ObjectId, ref: 'User'
	contact: type: Types.ObjectId, ref: 'Contact', required: true
	saved: type: Date

schemas.push Schema 'Exclude',
	user: type: Types.ObjectId, ref: 'User'
	contact: type: Types.ObjectId, ref: 'Contact'

schemas.push Schema 'User',
	email: type: String, required: true, unique: true, trim: true, lowercase: true, validate: validators.isEmail
	name: type: String, required: true, trim: true
	picture: type: String, trim: true, validate: validators.isUrl
	oauth: type: String	# This would be required, but it might briefly be empty during the OAuth2 migration.
	lastParsed: type: Date
	lastLogin: type: Date
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
	lastRank: type: Number
	oldRanks: [type: Number]
	contactCount: type: Number
	dataCount: type: Number
	oldDcounts: [type: Number]
	fullCount: type: Number
	unclassifiedCount: type: Number
	oldCcounts: [type: Number]
	lastLink:
		date: type: Date
		count: type: Number


schemas.push Schema 'Measurement',
	user: type: Types.ObjectId, ref: 'User'
	contact: type: Types.ObjectId, ref: 'Contact'
	attribute: type: String
	value: type: Number

schemas.push Schema 'Contact',
	emails: [ type: String ]
	names: [ type: String ]
	sortname: type:String, lowercase:true
	picture: type: String, trim: true, validate: validators.isUrl
	knows: [ type: Types.ObjectId, ref: 'User' ]
	added: type: Date
	addedBy: type: Types.ObjectId, ref: 'User'
	classified: type: Date
	updated: type: Date
	updatedBy: type: Types.ObjectId, ref: 'User'
	position: type: String, trim: true
	company: type: String, trim: true
	yearsExperience: type: Number
	isVip: type: Boolean
	linkedin: type: String, trim: true, match: util.socialPatterns.linkedin
	twitter: type: String, trim: true, match: util.socialPatterns.twitter
	facebook: type: String, trim: true, match: util.socialPatterns.facebook

schemas.push Schema 'Tag',
	creator: type: Types.ObjectId, ref: 'User', sparse: true
	contact: type: Types.ObjectId, ref: 'Contact', sparse: true
	category: type:String, required:true
	body: type: String, required: true, trim: true, lowercase: true

schemas.push Schema 'Note',
	author: type: Types.ObjectId, ref: 'User', required: true
	contact: type: Types.ObjectId, ref: 'Contact', required: true
	body: type: String, required: true, trim: true

schemas.push Schema 'Mail',
	sender: type: Types.ObjectId, ref: 'User', required: true
	recipient: type: Types.ObjectId, ref: 'Contact', required: true
	subject: type: String, trim: true
	sent: type: Date

schemas.push Schema 'IntroMail',
	sender: type: Types.ObjectId, ref: 'User', required: true
	recipient: type: Types.ObjectId, ref: 'User', required: true
	contact: type: Types.ObjectId, ref: 'Contact', required: true

schemas.push Schema 'LinkedIn',
	users: [ type: Types.ObjectId, ref: 'User' ]
	# TODO: fix schema design error: change user (ref) to users (array of refs)
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


schemas.push Schema 'Merge',
	contacts: [type: Types.Mixed]


schemas.push Schema 'FullContact',
	contact: type: Types.ObjectId, ref: 'Contact'
	contactInfo:
		familyName: type: String
		givenName: type: String
		fullName: type: String
	websites: [type: String]
	chats: [
		handle: type: String
		client: type: String
	]
	demographics:
		age: type: String
		locationGeneral: type: String
		gender: type: String
		ageRange: type: String
	photos: [
		typeId: type: String
		typeName: type: String
		url: type: String
		isPrimary: type: Boolean
	]
	socialProfiles: [
		typeId: type: String
		typeName: type: String
		id: type: String
		username: type: String
		url: type: String
		bio: type: String
		rss: type: String
		following: type: String
		followers: type: String
	]
	digitalFootprint:
		topics: [
			value: type: String
			provider: type: String
		]
		scores: [
			value: type: Number
			provider: type: String
			type: type: String
		]
	organizations: [
		title: type: String
		name: type: String
		startDate: type: String
		isPrimary: type: Boolean
	]
	enhancedData: [
		isPrimary: type: Boolean
		url: type: String
	]


schemas.push Schema 'Response',
	contact: [ type: Types.ObjectId, ref: 'Contact' ]
	body: type: String
	user: type: Types.ObjectId, ref: 'User'

schemas.push Schema 'Request',
	user: type: Types.ObjectId, ref: 'User'
	response: [ type: Types.ObjectId, ref: 'Response' ]
	text: type: String, required: true
	urgent: type: Boolean
	expiry: type: Date
	sent: type: Date
	updated: type: Boolean
	updatesent: type: Date


exports.all = ->
	schemas

for schema in schemas
	exports[schema.name] = schema
schemasUtil.addTimestamp exports.all()

