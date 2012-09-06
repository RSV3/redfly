config = 
	# all:


	development:
		HOST: 'localhost:5000'
		NODE_ENV: 'development'
		# INTERCEPT_EMAIL: 'pharcosyle.enterprise+redfly_development_intercept@gmail.com'

		MONGOLAB_URI: 'mongodb://heroku_app6379653:p1kafm34rqlg2a233c700j0bcj@ds037067-a.mongolab.com:37067/heroku_app6379653'

		REDISTOGO_URL: 'redis://redistogo:d8fafc860dfba6c9d50b6dbabc90653b@koi.redistogo.com:9609/'
		
		SENDGRID_USERNAME: 'app6379653@heroku.com'
		SENDGRID_PASSWORD: 'lxjmkfhw'


	test:
		HOST: 'redfly-test.herokuapp.com'	# 'test.redfly.com'
		NODE_ENV: 'development'
		# INTERCEPT_EMAIL: 'pharcosyle.enterprise+redfly_test_intercept@gmail.com'


	staging:
		HOST: 'redfly-staging.herokuapp.com'	# 'staging.redfly.com'
		NODE_ENV: 'production'
		# INTERCEPT_EMAIL: 'pharcosyle.enterprise+redfly_staging_intercept@gmail.com'

		MINIFY: true


	production:
		HOST: 'redfly-prod.herokuapp.com'	# 'www.redfly.com'
		NODE_ENV: 'production'

		MINIFY: true



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