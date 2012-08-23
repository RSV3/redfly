user =
	id: '178'
	email: 'kbaranowski@redstar.com'
	oauth:
		token: '1/yypfkV2FmS_2BHEomTHYiYPFWr9Mv7SP7_Iip95Nph8',
		secret: 'UOhGFM77U1PJOkwKIy-cF4EO'
	last_parse_date: null





# nodemailer = require 'nodemailer'

# generator = nodemailer.createXOAuthGenerator
# 	user: user.email
# 	token: user.oauth.token
# 	tokenSecret: user.oauth.secret
# xoauth = generator.generate()

# oauth = require 'oauth-gmail'
# client = oauth.createClient callbackUrl: 'http://' + process.env.HOST + '/authorized'
# xoauth = client.xoauthString user.email, user.oauth.token, user.oauth.secret

# XOauth = require 'gmail-xoauth'
# asdf = new XOauth 'anonymous', 'anonymous'
# xoauth = asdf.generateIMAPXOauthString user.email, user.oauth.token, user.oauth.secret

# console.log xoauth


xoauth = 'R0VUIGh0dHBzOi8vbWFpbC5nb29nbGUuY29tL21haWwvYi9rYmFyYW5vd3NraUByZWRzdGFyLmNvbS9pbWFwLyBvYXV0aF9jb25zdW1lcl9rZXk9ImFub255bW91cyIsb2F1dGhfbm9uY2U9Ijg5NjA2MzcxMDAyMzY5NzkzNDMiLG9hdXRoX3NpZ25hdHVyZT0iZmFIRmpBZ1h4cTB1eGRHeXk1VzdQdUp5cW5VJTNEIixvYXV0aF9zaWduYXR1cmVfbWV0aG9kPSJITUFDLVNIQTEiLG9hdXRoX3RpbWVzdGFtcD0iMTM0NTcxMjI0NyIsb2F1dGhfdG9rZW49IjElMkZ5eXBma1YyRm1TXzJCSEVvbVRIWWlZUEZXcjlNdjdTUDdfSWlwOTVOcGg4IixvYXV0aF92ZXJzaW9uPSIxLjAi'


imap = require 'imap'
server = new imap.ImapConnection
	xoauth: xoauth
	host: 'imap.gmail.com'
	port: 993
	secure: true

server.connect (err) ->
	throw err if err
	server.openBox '[Gmail]/All Mail', true, (err, box) ->
		throw err if err

		# criteria = [['FROM', user.email]]
		# TODO XXX for testing
		criteria = [['FROM', 'annie@redstar.com']]
		if previous = user.last_parse_date
			criteria.unshift ['SINCE', previous]
		server.search criteria, (err, results) ->
			throw err if err

			contacts = {}
			parseAddress = (address) ->
				name: address[...address.lastIndexOf(' ')]
				email: address[address.indexOf('<') + 1...]

			# notifications.foundTotal results.length
			console.log results.length
			fetch = server.fetch results,
				request:
					headers: ['from', 'to', 'subject', 'date']
			
			fetch.on 'message', (msg) ->
				msg.on 'end', ->
					for to in msg.headers.to
						{name, email} = parseAddress to
						if email.indexOf('@redstar.com') is -1	# Only added non-redstar people as contacts.
							if contact = contacts[email]
								contact.count++
							else
								contacts[email] =
									name: name
									email: email
									date: +new Date
									knows:
										id: user.id
											first_email:
												date: new Date msg.headers.date[0]
												subject: msg.headers.subject[0]
											count: 1
					# notifications.completedEmail()
					console.dir msg.headers

			fetch.once 'message', (msg) ->
				msg.on 'end', ->
					from = msg.headers.from[0]
					{name} = parseAddress from
					# notifications.foundName name
					console.log name

			fetch.on 'end', ->
				# notifications.done contacts
				server.logout()
