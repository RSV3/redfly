util = require '../server/util'

options = do ->
	url = require('url').parse process.env.MONGOLAB_URI
	auth = url.auth.split ':'

	mongodb:
		host: url.hostname
		port: url.port
		username: auth[0]
		password: auth[1]
		db: util.trim url.pathname, '/'
	s3:
		key: process.env.AWS_ACCESS_KEY
		secret: process.env.AWS_SECRET_KEY
		bucket: process.env.S3_BACKUP_BUCKET

backup = require 'mongodb_s3_backup'
backup.sync options.mongodb, options.s3
