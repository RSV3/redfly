module.exports = (projectRoot) ->
	
	process.env.APP_ENV ?= 'development'
	config = require projectRoot + '/config'
	
	scopes = [config.all, config[process.env.APP_ENV]]
	try
		local = require projectRoot + '/config-local'
		scopes.push local
	catch

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
