_ = require 'underscore'
models = require './models'
validators = require('validator').validators

#
# this module looks up the contact's email using the fullcontact api
# populating the contact record with relevant fields,
# and returns the full response, to be stored for later use in a new fullcontact record
#
module.exports = (contact, cb)->
	if not contact or not contact.emails then return cb null
	models.FullContact.findOne {contact: contact}, (err, fc_rec)->
		if err or fc_rec then return cb null	# don't continue if there's already full data for this contact
		FCAPI = new require('fullcontact.js') process.env.FULLCONTACT_API_KEY
		FCAPI.person {email:contact.emails[0]}, (fullDeets)->
			if fullDeets.status isnt 200 then return cb null
			delete fullDeets.status

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
					switch profile.typeId
						when 'facebook' then contact.facebook = _.last profile.url.split '/'
						when 'twitter' then contact.twitter = _.last profile.url.split '/'
						when 'linkedin' then contact.linkedin = profile.id

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

