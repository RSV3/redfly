exports.connect = ->
	model = @model
	
	# Hide the reconnect link for a second after clicking it
	model.set 'hideReconnect', true
	setTimeout (->
		model.set 'hideReconnect', false
	), 1000
	model.socket.socket.connect()

exports.reload = ->
	window.location.reload()
