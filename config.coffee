module.exports =
	all:
		ORGANISATION_NAME: 'redstar'
		ORGANISATION_TITLE: 'Redstar'
		ORGANISATION_CONTACT: 'Come Classify to Fly High'
		ORGANISATION_EMAIL: 'tech@redstar.com'
		ORGANISATION_DOMAIN: 'redstar.com'
		ES_NAME: 'redstar'
		ORG_TAG_CATEGORIES: 'Role, Theme, Project'

		# one default admin
		ADMIN_EMAIL:	'kwan@redstar.com'

		URGENT_HOUR:	17		# this is when all the un-answered requests are resent
		EMPTY_HOUR:		11		# this is when all the un-answered requests (urgent and otherwise) get resent

		PLUGIN_URL: 'https://chrome.google.com/webstore/detail/pmhekbfebpnlmdpnffgbdmgmnkaamolg'

	development:
		#HOST: '127.0.0.1:5000'
		HOST:	'10.0.0.8:5000'
		AUTO_AUTH: '50f7716ac458e60200000007'
		NODE_ENV: 'development'
		INTERCEPT_EMAIL: 'justin@justat.in'

		#GOOGLE_API_ID: '297124502120-mpum1g53cpt08er8q7o5nv864lu57uem.apps.googleusercontent.com'
		#GOOGLE_API_SECRET: 'dQ52vGIXziyxz26LSCrDz-rC'
		GOOGLE_API_SECRET: 'myZRXKo7S2iQVDpFxQ2bRzjE'
		GOOGLE_API_ID: '473151298751.apps.googleusercontent.com'

		LINKEDIN_API_KEY: '1g1zfsv0gan1'
		LINKEDIN_API_SECRET: 'tndJIY2VyDODvobq'

		CONTEXTIO_KEY: 'tjwypeyu'
		CONTEXTIO_SECRET: 'S6Y61Fgm0aIitFBV'

		# these defaults should be overridable in the client
		CONTEXTIO_SERVER: 'imap.googlemail.com'
		CONTEXTIO_PORT: '993'
		CONTEXTIO_SSL: '1'

		FULLCONTACT_API_KEY:	'f162c93405d0f7d7'

		MONGOLAB_URI: 'mongodb://heroku_app6379653:2vos1gak0e63rjl5220mluubm6@ds043837.mongolab.com:43837/heroku_app6379653'
		#MONGOLAB_URI: 'mongodb://localhost/redfly'

		#REDISTOGO_URL: 'redis://redistogo:d8fafc860dfba6c9d50b6dbabc90653b@koi.redistogo.com:9609/'
		REDISTOGO_URL: 'redis://redistogo:6bc53b4afcb65dd6e7e3fa6242b5e744@beardfish.redistogo.com:9484/'

		ES_URL: 'http://paas:fee2bc06df50ed0f4ddc123686ffbcc5@api.searchbox.io'
		
		SENDGRID_USERNAME: 'app6379653@heroku.com'
		SENDGRID_PASSWORD: 'lxjmkfhw'
		NUDGE_DAYS: 'Tuesday'

		ADMIN_EMAIL:	['kwan@redstar.com', 'justin@redstar.com']
		ORGANISATION_DOMAINS: ['redstar.com', 'vinely.com', 'justat.at']
		AUTH_DOMAINS: ['redstar.com', 'gmail.com', 'r-w.in']


	onboarding:
		# for testing fresh new onboarding of users

		HOST: 'redfly-test.herokuapp.com'	# 'staging.redfly.com'
		NODE_ENV: 'production'
		INTERCEPT_EMAIL: 'kwan+redfly_test@redstar.com, justin+redfly_test@redstar.com'

		GOOGLE_API_ID: '614207063627-g9m7b7c23cmtpueqhqlr6k3pghv18jsp.apps.googleusercontent.com'
		GOOGLE_API_SECRET: 'aqbMdiK5EyYjxANPI5_2wQsQ'

		LINKEDIN_API_KEY: 'jfztm93esgrb'
		LINKEDIN_API_SECRET: 'S8kdvese40NdC4Dg'

		MONGOLAB_URI: 'mongodb://heroku_app6375910:uaqkc8grn41ns5k2c2dngdo94k@ds033018.mongolab.com:33018/heroku_app6375910'

		FULLCONTACT_API_KEY:	'f162c93405d0f7d7'

		NUDGE_DAYS: 'Monday Thursday'



	staging:
		HOST: 'redfly-staging.herokuapp.com'	# 'staging.redfly.com'
		NODE_ENV: 'production'
		INTERCEPT_EMAIL: 'kwan+redfly_staging@redstar.com, justin+redfly_staging@redstar.com'

		GOOGLE_API_ID: '614207063627.apps.googleusercontent.com'
		GOOGLE_API_SECRET: 'FQb9jDmeN8btcR6pLnXx_jMZ'

		LINKEDIN_API_KEY: 'dmniuz3esjfd'
		LINKEDIN_API_SECRET: 'lUEtRHIlApJ8NKt9'

		MONGOLAB_URI: 'mongodb://heroku_app6375934:oc78rcclpfcs9iu3i8prldlki3@ds043847.mongolab.com:43847/heroku_app6375934'

		FULLCONTACT_API_KEY:	'f162c93405d0f7d7'

		ES_URL: 'http://paas:4766d4887993f5018fa1132ea5012002@api.searchbox.io'

		NUDGE_DAYS: 'Monday Thursday'



	project11staging:
		ORGANISATION_TITLE: 'Project11'
		ORGANISATION_DOMAIN: 'gmail.com'

		HOST: 'project11-staging.herokuapp.com'
		NODE_ENV: 'production'
		INTERCEPT_EMAIL: 'kwan+redfly_staging@redstar.com, justin+redfly_staging@redstar.com'

		GOOGLE_API_ID: '614207063627-ukni5v8eln764hh11nqa4tg8dcs1bhh5.apps.googleusercontent.com'
		GOOGLE_API_SECRET: 'Xhp-YRSc2xxOH_3c3KVjZRBQ'
		LINKEDIN_API_KEY: '5cbdonom6b77'
		LINKEDIN_API_SECRET: 'Z6kn0jAFC8wQCflH'
		FULLCONTACT_API_KEY:	'f162c93405d0f7d7'

		MONGOLAB_URI: 'mongodb://heroku_app18594187:56m25k6325f2i6489mc4kh2r3h@ds053858.mongolab.com:53858/heroku_app18594187'
		ES_URL: 'http://paas:041e4f042e1234537da0385d8305787b@api.searchbox.io'
		ES_NAME: 'project11'
		NUDGE_DAYS: 'Monday Thursday'

	project11prod:
		ORGANISATION_NAME: 'project11'
		ORGANISATION_TITLE: 'Project11'
		ORGANISATION_DOMAIN: 'project11.com'

		ADMIN_EMAIL:	'bob@project11.com'

		HOST: 'project11.joinlite.com'
		NODE_ENV: 'production'

		GOOGLE_API_ID: '614207063627-ndqice8qdhlj3nceeabj6b7gh3hpdq0m.apps.googleusercontent.com'
		GOOGLE_API_SECRET: '7hKRTdehivsmA_bqs9aoZMY1'
		LINKEDIN_API_KEY: '5cbdonom6b77'
		LINKEDIN_API_SECRET: 'Z6kn0jAFC8wQCflH'
		FULLCONTACT_API_KEY:	'f162c93405d0f7d7'

		MONGOLAB_URI: 'mongodb://heroku_app18594197:ot6gs4lpocaheo262u60uclfq7@ds059868-a0.mongolab.com:59868/heroku_app18594197'
		ES_URL: 'http://paas:715d2306105df387ab3b3f22dc62371a@api.searchbox.io'
		ES_NAME: 'project11'

		FULLCONTACT_API_KEY:	'f162c93405d0f7d7'

		NUDGE_DAYS: 'Tuesday Friday'
		NEWRELIC_KEY: 'abdc02b44f2ac6f422d61ee034da9c8906097cf6'

	production:
		HOST: 'redfly.redstar.com'
		NODE_ENV: 'production'

		GOOGLE_API_ID: '614207063627-rg8v0hi2l04h90h6s0umhjinv4rhavm1.apps.googleusercontent.com'
		GOOGLE_API_SECRET: '7WcNC-SBlZcOVfkjy_vIIT3s'

		LINKEDIN_API_KEY: 'wyctyn1vhpqn'
		LINKEDIN_API_SECRET: 'gDuJEXDNJb1BlUIZ'

		AWS_ACCESS_KEY: 'AKIAITJCEOND6UFFJA7Q'
		AWS_SECRET_KEY: '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'
		S3_BACKUP_BUCKET: 'backups.redfly.redstar.com'

		MONGOLAB_URI: 'mongodb://heroku_app8065862:6cqi48lldblomdf4uebuhplblj@ds039147.mongolab.com:39147/heroku_app8065862'

		ES_URL: 'http://paas:d39effca815a6a4d7a310d0c7974ea1a@api.searchbox.io'

		FULLCONTACT_API_KEY:	'f162c93405d0f7d7'

		NUDGE_DAYS: 'Tuesday Friday'
