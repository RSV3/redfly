doit = (type, name, data, cb)->
	if not cb
		cb = data	# often only two args ...
		data = null
	console.log "#{type}, #{name}"
	console.dir data
	$.ajax
		url: name
		type: 'GET'
		dataType: 'json'
		data: data
		xhrFields: withCredentials: true
		success: (data, textStatus, xhr)->
			console.log 'success'
			console.dir data
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
