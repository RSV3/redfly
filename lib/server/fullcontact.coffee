_ = require 'underscore'
models = require './models'
addTags = require './addtags'
validators = require('validator').validators
fullcontact = require 'fullcontact.js'

#
# this module looks up the contact's email using the fullcontact api
# populating the contact record with relevant fields,
# and storing everything for later use in a new fullcontact record
# there's no parameter to the callback
#
module.exports = (user, contact, cb)->
	fc = new fullcontact process.env.FULLCONTACT_API_KEY
	fc.person {email:contact.emails[0]}, (fullDeets)->
		if fullDeets.status isnt 200 then return cb()
		delete fullDeets.status
		fullDeets.user = user._id

		if not _.contains contact.names, fullDeets.contactInfo.fullName 
			contact.names.push fullDeets.contactInfo.fullName
		catname = "#{fullDeets.contactInfo.givenName} #{fullDeets.contactInfo.familyName}"
		if not _.contains contact.names, catname
			contact.names.push catname

		if fullDeets.emailAddresses
			for eddress in fullDeets.emailAddresses
				if not _.contains contact.emails eddress
					contact.emails.push eddress

		if fullDeets.socialProfile
			for profile in fullDeets.socialProfile
				switch profile.typeid
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

		if fullDeets.digitalFootprint
			addTags user, contact, 'industry', _.pluck(fullDeets.digitalFootprint.topics, 'value')

		newf = new models.FullContact fullDeets

		newf.save (err)-> console.dir err
		cb()

