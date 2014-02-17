
# TO-DO pretty sure I don't need to be threading (user, notifications, cb) through all the inner fuctions...
#
module.exports = (user, notifications, cb, succinct_manual) ->
	_ = require 'underscore'
	Mailer = require './mail'
	Models = require './models'
	LinkLater = require './linklater'
	ScrapeLI = require './linkscraper'
	AddTags = require './addtags'
	GetFC = require './fullcontact'
	Mboxer = require './mboxer'

	_saveMail = (user, contact, mail, done) ->
		newm = {sender:user, recipient:contact, subject:mail.subject, sent:mail.sent}
		Models.Mail.findOne newm, (err, rec) ->
			if not err and rec
				console.log "not going to store duplicate mail"
				console.dir rec
				return done()
			Models.Mail.create newm, (err) ->
				if err
					console.log "Error saving Mail record"
					console.dir err
					console.dir newm
					return done()
				Models.Classify.findOne {user:user, contact:contact, saved:$exists:true}, (err, classify)->
					if err
						console.log "Error finding classify for #{user}, #{contact}"
						console.dir err
						return done()
					if not classify then return done()
					classify.saved = require('moment')().toDate()		# update the saved stamp
					classify.save (err)->
						if err
							console.log "updating classify for #{user}, #{contact}"
							console.dir err
						return done()

	_saveFullContact = (contact, fullDeets) ->
		fullDeets.contact = contact
		Models.FullContact.create fullDeets, (err)->
			if err
				console.log "Error saving FullContact record"
				console.dir err
				console.dir fullDeets

	parse = (user, notifications, cb) ->
		Mboxer.connect user, (err, server)->
			if err		# Just log an error, send the newsletter and quit if the user can't be parsed.
				console.dir err
				if succinct_manual then return cb null
				return Mailer.sendNewsletter user, cb

			Mboxer.search server, user, (err, results) ->
				throw err if err
				mails = []
				notifications?.foundTotal? results.length
				finish = ->
					notifications?.completedAllEmails?()
					enqueue user, notifications, mails, cb
				if results.length is 0
					# Return statement is important, simply invoking the callback doesn't stop code from excuting in the current scope.
					return finish()
				Mboxer.eachMsg server, user, results, finish, (newmails)->
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
				retrydate = require('moment')(_.max(mails, (m)-> m.sent).sent).subtract(1, 'days').toDate()		# update the saved stamp
				user.lastParsed = retrydate
			user.save (err) ->
				if err
					console.log "Error saving lastParsed on #{user.name}"
					console.dir err
				if newContacts.length isnt 0
					Mailer.sendNudge user, newContacts[...10], (err)-> cb err
				else if not succinct_manual
					Mailer.sendNewsletter user, (err)-> cb err
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
			Models.Contact.find {emails: mail.recipientEmail}, (err, contacts) ->

				throw err if err
				if not contacts?.length then contact = null
				else
					contact = contacts[0]
					if contacts.length isnt 1
						console.log "ERROR: got #{contacts.length} results for #{mail.recipientEmail}"
						console.dir contacts

				splitted = mail.recipientEmail.split '@'
				domain = _.first _.last(splitted).split '.'
				mockname =  _.first(splitted) + " [#{domain}]"
				if contact then return _saveMail user, contact, mail, ->	# if we found a contact, return after saving it on the mail
					dirty = null
					if not _.contains contact.emails, mail.recipientEmail
						dirty = contact.emails.addToSet mail.recipientEmail
					if name = mail.recipientName
						if contact.names?.length and contact.names[0] is mockname
							contact.names.shift()
							contact.names.unshift name
							dirty = contact.sortname = name.toLowerCase()
						else if not _.contains contact.names, name
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
				contact = new Models.Contact
				contact.emails.addToSet mail.recipientEmail
				if not (name = mail.recipientName) then name = mockname
				contact.names.addToSet name
				contact.sortname = name.toLowerCase()
				contact.knows.addToSet user
				newContacts.push contact
				notifications?.foundNewContact?()

				return LinkLater.linkLater user, contact, ()->
					contact.save (err) ->		# new contact has been populated with any old data from LI
						if err
							console.log "Error saving Contact data for new user"
							console.dir err
							console.dir contact
							return sift index

						ScrapeLI.matchScraped contact, (scraped)->
							if scraped
								LinkLater.addDeets2Contact null, user, contact, scraped

						_saveMail user, contact, mail, ->
							sift index
							# then, sometime in the not too distant future, go and slowly get the FC data
							GetFC contact, (fullDeets) ->
								if fullDeets then contact.save (err) ->		# if we get data, save it
									if err
										console.log "Error saving Contact with FC data in initial parse"
										console.dir err
										console.dir contact
									_saveFullContact contact, fullDeets
									if fullDeets.digitalFootprint
										AddTags user, contact, 'industry', _.pluck(fullDeets.digitalFootprint.topics, 'value')


		sift()



# when we require this module, the parser method is called with the parameters provided
#
# email for user is parsed (since lastParsed)
# If the notifications object has the right vectors they fire during the process
# the callback is called with a list of new contacts

	parse user, notifications, cb
