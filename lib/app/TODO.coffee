# TODO XXX

		# if params.query.signup
		# 	model.set '_showLoader', true



		done = false


		user = model.at('_user').get()
		loading = null

		currentModel = model.at '_loadercurrent'
		totalModel = model.at '_loadertotal'

		socket.emit 'parse', user._id, ->
			loading.effect 'bounce'
			loading.pnotify type: 'success', closer: true
			App.User.find _id: App.user._id	# Classify queue has been determined and saved on the server, refresh by querying the store.
		socket.on 'parse.total', (total) ->
			currentModel.set 0
			totalModel.set total
			loading = $.pnotify loadingOptions
		socket.on 'parse.name', ->
			App.User.find _id: App.user._id	# We just figured out the logged-in user's name, refesh by querying the store.
		socket.on 'parse.update', ->
			currentModel.incr()

		model.fn '_loaderpercent', '_loadercurrent', '_loadertotal', (current, total) ->
			if not current or not total
				return 0
			Math.round (current / total) * 100

		$ ->
			$('#signupMessage').modal();


loadingOptions =
	title: 'Email parsing status',
	text: '<div id="loading"></div>'
	type: 'info'
	# nonblock: true
	hide: false
	closer: false
	sticker: false
	icon: 'icon-envelope'
	animate_speed: 700
	opacity: 0.9
	animation:
		effect_in: 'drop'
		options_in: direction: 'up'
		effect_out: 'drop'
		options_out: direction: 'right'
	before_open: (pnotify) ->
		pnotify.css top: '60px'
		$('#loadingStarted').appendTo '#loading'
