user =
	email: 'kbaranowski@redstar.com'
	oauth:
		token: '1/yypfkV2FmS_2BHEomTHYiYPFWr9Mv7SP7_Iip95Nph8',
		secret: 'UOhGFM77U1PJOkwKIy-cF4EO'

# TODO set last parse date

last_parse_date = null

# This example script opens an IMAP connection to the server and
# seeks unread messages sent by the user himself. It will then
# download those messages, parse them, and write their attachments
# to disk.

imap = require 'imap'
mailparser = require 'mailparser'
nodemailer = require 'nodemailer'

generator = nodemailer.createXOAuthGenerator
	user: user.email
	token: user.oauth.token
	tokenSecret: user.oauth.secret
xoauth = generator.generate()

# oauth = require 'oauth-gmail'
# client = oauth.createClient callbackUrl: 'http://' + process.env.HOST + '/authorized'
# xoauth = client.xoauthString user.email, user.oauth.token, user.oauth.secret

# XOauth = require 'gmail-xoauth'
# asdf = new XOauth 'anonymous', 'anonymous'
# xoauth = asdf.generateIMAPXOauthString user.email, user.oauth.token, user.oauth.secret

server = new imap.ImapConnection
	# username: user.email
	# password: '47alphatango'
	xoauth: xoauth
	host: 'imap.gmail.com'
	port: 993
	secure: true

console.log xoauth

server.connect (err) ->
	throw err if err
	server.openBox 'All Mail', false, (err, box) ->
		throw err if err

		server.search [['SINCE', 'Sep 18, 2011'], ['FROM', email]], (err, results) ->
			throw err if err

			unless results.length
				console.log 'No unread messages from #{config.email}'
				do server.logout
				return

			fetch = server.fetch results,
				request:
					body: 'full'
					headers: false
			
			fetch.on 'message', (message) ->
				fds = {}
				filenames = {}
				parser = new mailparser.MailParser

				parser.on 'headers', (headers) ->
					console.log 'Message: #{headers.subject}'

				parser.on 'astart', (id, headers) ->
					filenames[id] = headers.filename
					fds[id] = fs.openSync headers.filename, 'w'

				parser.on 'astream', (id, buffer) ->
					fs.writeSync fds[id], buffer, 0, buffer.length, null

				parser.on 'aend', (id) ->
					return unless fds[id]
					fs.close fds[id], (err) ->
						return console.error err if err
						console.log 'Writing #{filenames[id]} completed'

				message.on 'data', (data) ->
					parser.feed data.toString()

				message.on 'end', ->
					do parser.end

			fetch.on 'end', ->
				do server.logout

