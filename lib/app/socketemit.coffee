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
			cb data
		error: (xhr, textStatus, errorThrown)->
			console.log 'error'
			console.dir textStatus
			cb null

module.exports =
	get: (name, data, cb)->
		doit 'GET', name, data, cb
	post: (name, data, cb)->
		doit 'POST', name, data, cb
