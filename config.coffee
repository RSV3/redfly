config = 
	# all:


	development:
		HOST: 'localhost:5000'
		NODE_ENV: 'development'
		INTERCEPT_EMAIL: 'pharcosyle.enterprise+redfly_development_intercept@gmail.com'

		MONGOLAB_URI: 'mongodb://heroku_app6379653:r6dae13oimgpm3vjsm8fjnle19@ds043467.mongolab.com:43467/heroku_app6379653'

		REDISTOGO_URL: 'redis://redistogo:d8fafc860dfba6c9d50b6dbabc90653b@koi.redistogo.com:9609/'
		
		SENDGRID_USERNAME: 'app6379653@heroku.com'
		SENDGRID_PASSWORD: 'lxjmkfhw'


	test:
		HOST: 'redfly-test.herokuapp.com'	# 'test.redfly.com'
		NODE_ENV: 'development'
		INTERCEPT_EMAIL: 'pharcosyle.enterprise+redfly_test_intercept@gmail.com, kwan+redfly_test@redstar.com'

		MONGOLAB_URI: 'mongodb://heroku_app6375910:osf31ssqike03ju6i6852jd0v2@ds037097-a.mongolab.com:37097/heroku_app6375910'


	staging:
		HOST: 'redfly-staging.herokuapp.com'	# 'staging.redfly.com'
		NODE_ENV: 'production'
		INTERCEPT_EMAIL: 'pharcosyle.enterprise+redfly_staging_intercept@gmail.com, kwan+redfly_staging@redstar.com'

		MONGOLAB_URI: 'mongodb://heroku_app6375934:oulrbvefpj1gho0o6mq9n77t4h@ds037067-a.mongolab.com:37067/heroku_app6375934'

		NUDGE_DAY: 'Thursday'


	production:
		HOST: 'redfly.redstar.com'
		NODE_ENV: 'production'
		INTERCEPT_EMAIL: 'pharcosyle.enterprise+redfly_test_intercept@gmail.com, kwan+redfly_test@redstar.com'


		MONGOLAB_URI: 'mongodb://heroku_app8065862:6cqi48lldblomdf4uebuhplblj@ds039147.mongolab.com:39147/heroku_app8065862'

		S3_ACCESS_KEY: 'AKIAITJCEOND6UFFJA7Q'
		S3_SECRET_KEY: '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'
		BACKUP_BUCKET: 'backups.redfly.redstar.com'

		NUDGE_DAY: 'Wednesday'



process.env.APP_ENV ?= 'development'

scopes = [config.all, config[process.env.APP_ENV]]
try
	local = require './config-local'
	scopes.push local
catch err

for scope in scopes
	for variable of scope
		process.env[variable] = scope[variable]



#	request = require 'request'
# 	if process.env.APP_ENV is 'development'
# 		request
# 			uri: 'https://api.heroku.com/apps/' +  + '/config_vars'
# 			headers:
# 				Accept: 'application/json'
# 			auth: ':' + 
# 			(err, res, body) ->
# 				throw err if err
# 				throw new Error if res.statusCode isnt 200
# 				scopes.unshift JSON.parse body