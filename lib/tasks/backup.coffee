util = require '../server/util'

url = require('url').parse process.env.MONGOLAB_URI
auth = url.auth.split ':'

options =
	mongodb:
		host: url.hostname
		port: url.port
		username: auth[0]
		password: auth[1]
		db: util.trim url.pathname, '/'
	s3:
		key: process.env.S3_ACCESS_KEY
		secret: process.env.S3_SECRET_KEY
		bucket: process.env.BACKUP_BUCKET

backup = require 'mongodb_s3_backup'
backup.sync options.mongodb, options.s3
