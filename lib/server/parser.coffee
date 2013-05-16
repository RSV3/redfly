
# TO-DO pretty sure I don't need to be threading (user, notifications, cb) through all the inner fuctions...
#
module.exports = (user, notifications, cb, succinct_manual) ->
	_ = require 'underscore'
	mailer = require './mail'
	models = require './models'
	linkLater = require('./linklater').linkLater;
	addTags = require './addtags'
	getFC = require './fullcontact'
	mboxer = require './mboxer'

	_saveMail = (user, contact, mail) ->
		mail.sender = user
		mail.recipient = contact
		models.Mail.create mail, (err) ->
			if err
				console.log "Error saving Mail record"
				console.dir err
				console.dir mail

	_saveFullContact = (user, contact, fullDeets) ->
		fullDeets.contact = contact
		models.FullContact.create fullDeets, (err)->
			if err
				console.log "Error saving FullContact record"
				console.dir err
				console.dir fullDeets

	parse = (user, notifications, cb) ->
		mboxer.connect user, (err, server)->
			if err
				console.dir err
				# Just send the newsletter and quit if the user can't be parsed.
				if succinct_manual then return cb null
				return mailer.sendNewsletter user, cb

			mboxer.search server, user, (err, results) ->
				throw err if err
				mails = []
				notifications?.foundTotal? results.length
				finish = ->
					notifications?.completedAllEmails?()
					enqueue user, notifications, mails, cb
				if results.length is 0
					# Return statement is important, simply invoking the callback doesn't stop code from excuting in the current scope.
					return finish()
				mboxer.eachMsg server, user, results, finish, (newmails)->
					notifications?.completedEmail?()
					mails = mails.concat newmails



	#
	# jTNT added succinct_manual flag so that we can manually nudge
	# without bothering users who don't have new contacts
	# this way, if nudge -ahem- fails part way through,
	# we can resume with manual set, without risking bothering those
	# who already received an email before the fail.
	#
	enqueue = (user, notifications, mails, cb) ->
		newContacts = []
		finish = ->
			if mails and mails.length
				user.lastParsed = _.max(mails, (m)-> m.sent).sent
			user.save (err) ->
				if err
					console.log "Error saving lastParsed on #{user.name}"
					console.dir err
				if newContacts.length isnt 0
					mailer.sendNudge user, newContacts[...10], (err)-> cb err
				else if not succinct_manual
					mailer.sendNewsletter user, (err)-> cb err
				else cb null

		sift = (index = 0) ->
			if mails.length is 0 then return finish()
			if index > mails.length
				if newContacts.length
					newContacts = _.sortBy newContacts, (contact) ->
						_.chain(mails)
							.filter (mail) ->
								mail.recipient is contact
							.max (mail) ->
								mail.sent.getTime() # TO-DO probably can be just mail.sent
							.value()
					newContacts.reverse()
					#user.queue.unshift newContacts... # dont use queue on user object anymore
				return finish()

			if not (mail = mails[index++]) then return sift index

			notifications?.considerContact?()
			# Find an existing contact with one of the same emails 
			# models.Contact.findOne $or: [{emails: mail.recipientEmail}, {names: mail.recipientName}], (err, contact) ->
			models.Contact.findOne {emails: mail.recipientEmail}, (err, contact) ->
				throw err if err
				if contact
					_saveMail user, contact, mail
					dirty = null
					if not _.contains contact.emails, mail.recipientEmail
						dirty = contact.emails.addToSet mail.recipientEmail
					if name = mail.recipientName
						if not _.contains contact.names, name
							dirty = contact.names.addToSet name
					if not _.contains contact.knows, user
						dirty = contact.knows.addToSet user
					if not dirty then return sift index
					return contact.save (err) ->	# existing contact has been updated
						if err
							console.log "ERRor saving Contact"
							console.dir err
							console.dir contact
						sift index

				# only gets here if we didn't find contact

				contact = new models.Contact
				contact.emails.addToSet mail.recipientEmail
				if name = mail.recipientName then contact.names.addToSet name
				newContacts.push contact
				notifications?.foundNewContact?()
				contact.knows.addToSet user

				#
				# If this is the regular nudge, notifications will be null: get fullcontact data.
				# If this is a load on initial log in, don't use fullcontact (it's too long to wait)
				#  - we'll pick up the slack in the background
				#
				# So these two cases have a slightly different order of operations

				#
				# this one's the load on initial sign up (hit the '/load' link)
				# see the return: doesn't proceed past this block.
				#
				# or atleast we used to. but that makes it take too long, so ...
				#if notifications then

				return linkLater user, contact, ()->
					contact.save (err) ->		# new contact has been populated with any old data from LI
						if err
							console.log "Error saving Contact data for new user"
							console.dir err
							console.dir contact
							sift index
						else
							_saveMail user, contact, mail
							sift index
							# then, sometime in the not too distant future, go and slowly get the FC data
							console.log "calling FC"
							console.dir contact
							getFC contact, (fullDeets) ->
								console.log "called FC"
								console.dir contact
								if fullDeets then contact.save (err) ->		# if we get data, save it
									if err
										console.log "Error saving Contact with FC data in initial parse"
										console.dir err
										console.dir contact
									_saveFullContact user, contact, fullDeets
									if fullDeets.digitalFootprint
											addTags user, contact, 'industry', _.pluck(fullDeets.digitalFootprint.topics, 'value')

				# only gets here iff no notifications (ie. this is part of an out of session batch task)
				###

				getFC contact, (fullDeets) ->
					linkLater user, contact, ()->
						contact.save (err) ->		# new contact, populated with any data from FC and LI
							if err
								console.log "Error saving Contact with FullContact data"
								console.dir err
								console.dir contact
							else	# now save other records that need the contact reference: mail, FC, tags
								_saveMail user, contact, mail
								if fullDeets
									_saveFullContact user, contact, fullDeets
									if fullDeets.digitalFootprint
										addTags user, contact, 'industry', _.pluck(fullDeets.digitalFootprint.topics, 'value')
							sift index
				###

		sift()



# when we require this module, the parser method is called with the parameters provided
#
# email for user is parsed (since lastParsed)
# If the notifications object has the right vectors they fire during the process
# the callback is called with a list of new contacts

	parse user, notifications, cb
