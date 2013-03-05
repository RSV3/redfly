module.exports =
	all:
		ORGANISATION_NAME: 'darwin'
		ORGANISATION_TITLE: 'Da.r-w.in'
		ORGANISATION_CONTACT: 'justin B. tutty'
		ORGANISATION_EMAIL: 'd@r-w.in'
		ORGANISATION_DOMAIN: 'da.r-w.in'


	development:
		HOST: 'localhost:5000'
		#AUTO_AUTH: '50ed206d4919709c08000002'
		NODE_ENV: 'development'
		INTERCEPT_EMAIL: 'just@justat.at'

		GOOGLE_API_ID: '297124502120-mpum1g53cpt08er8q7o5nv864lu57uem.apps.googleusercontent.com'
		GOOGLE_API_SECRET: 'dQ52vGIXziyxz26LSCrDz-rC'

		LINKEDIN_API_KEY: '1g1zfsv0gan1'
		LINKEDIN_API_SECRET: 'tndJIY2VyDODvobq'

		MONGOLAB_URI: 'mongodb://rfduser:rfdp455@ds039707.mongolab.com:39707/redflydarwin'

		REDISTOGO_URL: 'redis://redistogo:e8d8d65fbe7df9673b111dc8702c0796@barreleye.redistogo.com:9726/'
		
		SENDGRID_USERNAME: 'app6379653@heroku.com'
		SENDGRID_PASSWORD: 'lxjmkfhw'
		NUDGE_DAYS: 'Monday Thursday'


	staging:
		HOST: 'redfly-staging.herokuapp.com'	# 'staging.redfly.com'
		NODE_ENV: 'production'
		INTERCEPT_EMAIL: 'just@justat.at'

		GOOGLE_API_ID: '614207063627.apps.googleusercontent.com'
		GOOGLE_API_SECRET: 'FQb9jDmeN8btcR6pLnXx_jMZ'

		LINKEDIN_API_KEY: 'dmniuz3esjfd'
		LINKEDIN_API_SECRET: 'lUEtRHIlApJ8NKt9'

		MONGOLAB_URI: 'mongodb://heroku_app6375934:oc78rcclpfcs9iu3i8prldlki3@ds043847.mongolab.com:43847/heroku_app6375934'
		REDISTOGO_URL: 'redis://redistogo:e8d8d65fbe7df9673b111dc8702c0796@barreleye.redistogo.com:9726/'

		NUDGE_DAYS: 'Tuesday Thursday'


	production:
		HOST: 'redfly.rednot.com'
		NODE_ENV: 'production'

		GOOGLE_API_ID: '614207063627-rg8v0hi2l04h90h6s0umhjinv4rhavm1.apps.googleusercontent.com'
		GOOGLE_API_SECRET: '7WcNC-SBlZcOVfkjy_vIIT3s'

		LINKEDIN_API_KEY: 'wyctyn1vhpqn'
		LINKEDIN_API_SECRET: 'gDuJEXDNJb1BlUIZ'

		S3_ACCESS_KEY: 'AKIAITJCEOND6UFFJA7Q'
		S3_SECRET_KEY: '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'
		BACKUP_BUCKET: 'backups.redfly.rednot.com'

		MONGOLAB_URI: 'mongodb://heroku_app8065862:6cqi48lldblomdf4uebuhplblj@ds039147.mongolab.com:39147/heroku_app8065862'

		NUDGE_DAYS: 'Tuesday Friday'
