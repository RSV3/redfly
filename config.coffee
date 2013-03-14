module.exports =
	# all:


	development:
		HOST: 'redsite.loc:5000'
		AUTO_AUTH: '50f7716ac458e60200000007'
		NODE_ENV: 'development'
		INTERCEPT_EMAIL: 'justin@da.r-w.in'

		GOOGLE_API_ID: '297124502120-mpum1g53cpt08er8q7o5nv864lu57uem.apps.googleusercontent.com'
		GOOGLE_API_SECRET: 'dQ52vGIXziyxz26LSCrDz-rC'

		LINKEDIN_API_KEY: '1g1zfsv0gan1'
		LINKEDIN_API_SECRET: 'tndJIY2VyDODvobq'

		FULLCONTACT_API_KEY:	'f162c93405d0f7d7'

		MONGOLAB_URI: 'mongodb://heroku_app6379653:2vos1gak0e63rjl5220mluubm6@ds043837.mongolab.com:43837/heroku_app6379653'

		REDISTOGO_URL: 'redis://redistogo:d8fafc860dfba6c9d50b6dbabc90653b@koi.redistogo.com:9609/'
		
		SENDGRID_USERNAME: 'app6379653@heroku.com'
		SENDGRID_PASSWORD: 'lxjmkfhw'
		NUDGE_DAYS: 'Monday Thursday'


	# test:
	# 	HOST: 'redfly-test.herokuapp.com'	# 'test.redfly.com'
	# 	NODE_ENV: 'development'
	# 	INTERCEPT_EMAIL: 'kwan+redfly_test@redstar.com'

	# 	MONGOLAB_URI: 'mongodb://heroku_app6375910:osf31ssqike03ju6i6852jd0v2@ds037097-a.mongolab.com:37097/heroku_app6375910'

	#	# GOOGLE_API_ID: ''
	#	# GOOGLE_API_SECRET: ''


	staging:
		HOST: 'redfly-staging.herokuapp.com'	# 'staging.redfly.com'
		NODE_ENV: 'production'
		INTERCEPT_EMAIL: 'kwan+redfly_staging@redstar.com, justin+redfly_staging@redstar.com'

		GOOGLE_API_ID: '614207063627.apps.googleusercontent.com'
		GOOGLE_API_SECRET: 'FQb9jDmeN8btcR6pLnXx_jMZ'

		LINKEDIN_API_KEY: 'dmniuz3esjfd'
		LINKEDIN_API_SECRET: 'lUEtRHIlApJ8NKt9'

		MONGOLAB_URI: 'mongodb://heroku_app6375934:oc78rcclpfcs9iu3i8prldlki3@ds043847.mongolab.com:43847/heroku_app6375934'

		NUDGE_DAYS: 'Monday Thursday'


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

		NUDGE_DAYS: 'Tuesday Friday'
