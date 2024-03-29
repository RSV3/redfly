_ = require 'underscore'
models = require './models'
validators = require('validator').validators
request = require('request')

FCAPI_person = (options, cb) ->
	opts = apiKey: process.env.FULLCONTACT_API_KEY
	if options then for key of options
		opts[key] = options[key]
	try
		request {
			url: 'https://api.fullcontact.com/v2/person.json'
			qs: opts
		}, (e,r,b)->
			try
				if b then b = JSON.parse b
			catch err
				console.log "ERROR parsing FC response:"
				console.dir err
				console.dir b
				console.dir opts
				b = null
			if b?.status is 202 then setTimeout (()-> FCAPI_person opts, cb), 300000
			else cb b
	catch err
		console.log "ERROR doing FC query on:"
		console.dir opts
		console.dir err
		cb()


#
# this module looks up the contact's email using the fullcontact api
# populating the contact record with relevant fields,
# and returns the full response, to be stored for later use in a new fullcontact record
#
module.exports = (contact, cb)->
	if not contact or not contact.emails then return cb null
	models.FullContact.findOne {contact: contact._id}, (err, fc_rec)->
		if err or fc_rec then return cb null	# don't continue if there's already full data for this contact
		FCAPI_person {email:contact.emails[0]}, (fullDeets)->
			if not fullDeets or fullDeets.status isnt 200 then return cb null
			delete fullDeets.status

			if fullDeets.contactInfo
				if not _.contains contact.names, fullDeets.contactInfo.fullName
					contact.names.push fullDeets.contactInfo.fullName
				catname = "#{fullDeets.contactInfo.givenName} #{fullDeets.contactInfo.familyName}"
				if not _.contains contact.names, catname
					contact.names.push catname

			if fullDeets.emailAddresses
				for eddress in fullDeets.emailAddresses
					if not _.contains contact.emails eddress
						contact.emails.push eddress

			if fullDeets.socialProfiles
				for profile in fullDeets.socialProfiles
					if _.contains ['facebook', 'twitter', 'linkedin'], profile.typeId		# if its one of the networks we track
						contact[profile.typeId] = _.last profile.url.split '/'				# get the url segment after the last /
						if _.contains contact[profile.typeId], '='							# and if that has something like /?view=123
							contact[profile.typeId] = _.last contact[profile.typeId].split '='			# just get the ID after the '='

			if fullDeets.organizations
				for org in fullDeets.organizations
					if org.isPrimary
						if not contact.position then contact.position = org.title
						if not contact.company then contact.company = org.name
						# could calculate years experience from org.startdate ... not so accurate without industry

			if fullDeets.photos
				for photo in fullDeets.photos
					if photo.isPrimary and not contact.picture
						contact.picture = photo.url

			cb fullDeets

