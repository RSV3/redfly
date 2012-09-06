module.exports = (app) ->
	util = require '../util'


	send = (template, options, locals) ->
		locals ?= {}
		locals.path = (url) ->
			'http://' + process.env.HOST + url

		app.render template, locals, (err, html) ->
			throw err if err

			options.html = html
			options.from ?= 'Redfly Supreme Ninja <kbaranowski@redstar.com>'
			util.mail options


	sendWelcome: (to) ->
		send 'welcome',
			to: to
			subject: 'Thank you for joining Redfly!'
			# title is required

	sendNudge: (user, contacts) ->
		names = (contact.name for contact in contacts)
		firstNames = (name[...name.indexOf(' ')] for name in names)
		# TODO handle the 1 and 2 conctacs cases
		firstNameString = firstNames[0] + ', ' + firstNames[1] + ', and ' + firstNames[2]
		send 'nudge',
				to: user.to
				subject: 'Tell me more about ' + firstNameString + '...'
			,
			title: 'Hi ' + user.name + '!'
			names: names
			