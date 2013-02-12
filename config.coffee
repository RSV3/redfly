config = 
	# all:


	development:
		HOST: 'redsite.com:5000'
		NODE_ENV: 'development'
		INTERCEPT_EMAIL: 'pharcosyle+redfly_development_intercept@gmail.com'
		AUTO_AUTH: '50ed206d4919709c08000002'

		GOOGLE_API_ID: '297124502120-mpum1g53cpt08er8q7o5nv864lu57uem.apps.googleusercontent.com'
		GOOGLE_API_SECRET: 'dQ52vGIXziyxz26LSCrDz-rC'

		LINKEDIN_API_KEY: '1g1zfsv0gan1'
		LINKEDIN_API_SECRET: 'tndJIY2VyDODvobq'

		MONGOLAB_URI: 'mongodb://heroku_app6379653:2vos1gak0e63rjl5220mluubm6@ds043837.mongolab.com:43837/heroku_app6379653'

		REDISTOGO_URL: 'redis://redistogo:d8fafc860dfba6c9d50b6dbabc90653b@koi.redistogo.com:9609/'
		
		SENDGRID_USERNAME: 'app6379653@heroku.com'
		SENDGRID_PASSWORD: 'lxjmkfhw'


	# test:
	# 	HOST: 'redfly-test.herokuapp.com'	# 'test.redfly.com'
	# 	NODE_ENV: 'development'
	# 	INTERCEPT_EMAIL: 'pharcosyle+redfly_test_intercept@gmail.com, kwan+redfly_test@redstar.com'

	# 	MONGOLAB_URI: 'mongodb://heroku_app6375910:osf31ssqike03ju6i6852jd0v2@ds037097-a.mongolab.com:37097/heroku_app6375910'

	#	# GOOGLE_API_ID: ''
	#	# GOOGLE_API_SECRET: ''


	staging:
		HOST: 'redfly-staging.herokuapp.com'	# 'staging.redfly.com'
		NODE_ENV: 'production'
		INTERCEPT_EMAIL: 'pharcosyle+redfly_staging_intercept@gmail.com, kwan+redfly_staging@redstar.com'

		GOOGLE_API_ID: '614207063627.apps.googleusercontent.com'
		GOOGLE_API_SECRET: 'FQb9jDmeN8btcR6pLnXx_jMZ'

		LINKEDIN_API_KEY: 'dmniuz3esjfd'
		LINKEDIN_API_SECRET: 'lUEtRHIlApJ8NKt9'

		MONGOLAB_URI: 'mongodb://heroku_app6375934:oc78rcclpfcs9iu3i8prldlki3@ds043847.mongolab.com:43847/heroku_app6375934'

		NUDGE_DAY: 'Thursday'


	production:
		HOST: 'redfly.redstar.com'
		NODE_ENV: 'production'

		GOOGLE_API_ID: '614207063627-rg8v0hi2l04h90h6s0umhjinv4rhavm1.apps.googleusercontent.com'
		GOOGLE_API_SECRET: '7WcNC-SBlZcOVfkjy_vIIT3s'

		LINKEDIN_API_KEY: 'wyctyn1vhpqn'
		LINKEDIN_API_SECRET: 'gDuJEXDNJb1BlUIZ'

		S3_ACCESS_KEY: 'AKIAITJCEOND6UFFJA7Q'
		S3_SECRET_KEY: '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'
		BACKUP_BUCKET: 'backups.redfly.redstar.com'

		MONGOLAB_URI: 'mongodb://heroku_app8065862:6cqi48lldblomdf4uebuhplblj@ds039147.mongolab.com:39147/heroku_app8065862'

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
