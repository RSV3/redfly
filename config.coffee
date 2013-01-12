config = 
	# all:


	development:
		HOST: 'localhost:5000'
		NODE_ENV: 'development'
		INTERCEPT_EMAIL: 'pharcosyle+redfly_development_intercept@gmail.com'

		MONGOLAB_URI: 'mongodb://heroku_app6379653:2vos1gak0e63rjl5220mluubm6@ds043837.mongolab.com:43837/heroku_app6379653'

		REDISTOGO_URL: 'redis://redistogo:d8fafc860dfba6c9d50b6dbabc90653b@koi.redistogo.com:9609/'
		
		SENDGRID_USERNAME: 'app6379653@heroku.com'
		SENDGRID_PASSWORD: 'lxjmkfhw'

		GOOGLE_API_ID: '297124502120.apps.googleusercontent.com'
		GOOGLE_API_SECRET: 'HkTxwXiUzlWMRhc6UTQgMvpo'


	# test:
	# 	HOST: 'redfly-test.herokuapp.com'	# 'test.redfly.com'
	# 	NODE_ENV: 'development'
	# 	INTERCEPT_EMAIL: 'pharcosyle+redfly_test_intercept@gmail.com, kwan+redfly_test@redstar.com'

	# 	MONGOLAB_URI: 'mongodb://heroku_app6375910:osf31ssqike03ju6i6852jd0v2@ds037097-a.mongolab.com:37097/heroku_app6375910'

		# GOOGLE_API_ID: ''
		# GOOGLE_API_SECRET: ''


	staging:
		HOST: 'redfly-staging.herokuapp.com'	# 'staging.redfly.com'
		NODE_ENV: 'production'
		INTERCEPT_EMAIL: 'pharcosyle+redfly_staging_intercept@gmail.com, kwan+redfly_staging@redstar.com'

		MONGOLAB_URI: 'mongodb://heroku_app6375934:oc78rcclpfcs9iu3i8prldlki3@ds043847.mongolab.com:43847/heroku_app6375934'

		NUDGE_DAY: 'Thursday'

		GOOGLE_API_ID: '614207063627.apps.googleusercontent.com'
		GOOGLE_API_SECRET: 'FQb9jDmeN8btcR6pLnXx_jMZ'


	production:
		HOST: 'redfly.redstar.com'
		NODE_ENV: 'production'

		MONGOLAB_URI: 'mongodb://heroku_app8065862:6cqi48lldblomdf4uebuhplblj@ds039147.mongolab.com:39147/heroku_app8065862'

		S3_ACCESS_KEY: 'AKIAITJCEOND6UFFJA7Q'
		S3_SECRET_KEY: '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'
		BACKUP_BUCKET: 'backups.redfly.redstar.com'

		GOOGLE_API_ID: '614207063627.apps.googleusercontent.com'
		GOOGLE_API_SECRET: 'FQb9jDmeN8btcR6pLnXx_jMZ'

		NUDGE_DAY: 'Friday'



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
