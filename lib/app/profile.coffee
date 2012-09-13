{get, ready, view} = require './index'


common = (page, model, params) ->
	model.subscribe model.query('contacts').addedBy(profileUser.id), (err, contacts) ->
		model.ref '_contacts', contacts
		model.fn '_total', '_contacts', (contacts) ->
			contacts?.length or 0

		# if params.query.signup
		# 	model.set '_showLoader', true

		page.render 'profile'


getParameterByName = (name) ->
	name = name.replace(/[\[]/, "\\[").replace(/[\]]/, "\\]")
	regexS = "[\\?&]" + name + "=([^&#]*)"
	regex = new RegExp(regexS)
	results = regex.exec(window.location.search)
	unless results?
		""
	else
		decodeURIComponent results[1].replace(/\+/g, " ")

ready (model) ->
	# TODO this should all be in loader/index.coffee, but for some reason the create callback isn't firing
	if getParameterByName 'signup'

		user = model.at('_user').get()
		loading = null

		currentModel = model.at '_loadercurrent'
		totalModel = model.at '_loadertotal'

		socket = io.connect 'http://localhost:5000/myapp/loader' # TODO XXX make be not localhost (autodiscovery?), search for other calls like this
		socket.emit 'parse', user.id, ->
			loading.effect 'bounce'
			loading.pnotify type: 'success', closer: true
		socket.on 'start', (total) ->
			currentModel.set 0
			totalModel.set total
			loading = $.pnotify loadingOptions

			socket.on 'update', ->
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
