doit = (type, name, data, cb)->
	if not cb
		cb = data	# often only two args ...
		data = null
	$.ajax
		url: "/#{name}"
		cache:false
		type: 'GET'
		data: data
		beforeSend: (jqXHR, settings)->
			settings['HTTP_X_REQUESTED_WITH'] = 'XMLHttpRequest'
		success: (data, textStatus, xhr)->
			_ = require 'underscore'
			if _.isArray(data) and cb.prototype.constructor.length > 1
				return cb.apply cb, data	# allow callbacks to take list of args
			cb data			# ...but most commonly expect a single object response
		error: (xhr, textStatus, errorThrown)->
			console.log 'error'
			console.dir textStatus
			cb null

module.exports =
	get: (name, data, cb)->
		doit 'GET', name, data, cb
	post: (name, data, cb)->
		doit 'POST', name, data, cb
