# finish and use the derby Connection widget (connection.hbr/coffee) or get rid of it. I don't know what "reconnecting" really means or if
# it makes sense in my app, but if not the best thing to do when the connection is lost for long enough might be to show an un undismissable
# modal that says to 'check your internet connection' and have a big button that says "Refresh" or "Continue offline" (with the latter having
# a warning that anything you do offline won't be saved)


module.exports = (Ember, App) ->

	# TO-DO define 'connected' and 'canConnect' like derby does.
	App.ConnectionView = Ember.View.extend	# TO-DO probably inline this in appview # TO-DO does this have to be on the App object?
		template: require '../../../../templates/components/connection.jade'
		classNames: ['connection']
		###
		connect: ->
			# Hide the reconnect link for a second after clicking it.
			@set 'hideReconnect', true
			setTimeout (=>
				@set 'hideReconnect', false
			), 1000
			model.socket.socket.connect()	# TODO get socket
		###
		reload: ->
			window.location.reload()
