module.exports = (Ember, App, socket) ->


	App.LoaderView = Ember.View.extend
		template: require '../../../../views/templates/components/loader'

		# TODO hack. Actions target the view not the router for loaderview, probably becuause I added it manually
		goClassify: ->
			App.get('router').send 'goClassify'

		didInsertElement: ->
			$('#signupMessage').modal()	# TO-DO make scoped @$ when possible
			@set 'loading', $.pnotify
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
				before_open: (pnotify) =>
					pnotify.css top: '60px'
					@$('#loadingStarted').appendTo '#loading'

			# TODO replace state strings with a proper state machine
			# manager = Ember.StateManager.create
			# 	start: Ember.State.create()
			# 	parsing: Ember.State.create()
			# 	queueing: Ember.State.create()
			# 	end: Ember.State.create()

			@set 'stateConnecting', true
			@set 'stateParsing', false
			@set 'stateQueueing', false
			@set 'stateDone', false

			socket.emit 'parse', App.user.get('id'), (message) =>
				# TODO check if 'message' param exists, if so there was an error. Can also do error as a custom event if necessary. The alert is a
				# temporary mesasure
				if message
					alert message + ' Are you connected to the internet? Did you mistype your email?'
				else
					App.refresh App.user.get('content')	# Classify queue has been determined and saved on the server, refresh the user.	# TODO try without .get('content')
					@set 'stateConnecting', false
					@set 'stateParsing', false
					@set 'stateQueueing', false
					@set 'stateDone', true
					@get('loading').effect 'bounce'
					@get('loading').pnotify type: 'success', closer: true

			socket.on 'parse.total', (total) =>
				@set 'current', 0
				@set 'total', total
				socket.on 'parse.mail', =>
					@incrementProperty 'current'
				@set 'stateConnecting', false
				@set 'stateParsing', true
				@set 'stateQueueing', false
				@set 'stateDone', false

			socket.on 'parse.queueing', =>
				@set 'totalQueued', 0
				socket.on 'parse.queue', =>
					@incrementProperty 'totalQueued'
				@set 'stateConnecting', false
				@set 'stateParsing', false
				@set 'stateQueueing', true
				@set 'stateDone', false

			socket.on 'parse.name', =>
				App.refresh App.user.get('content')	# We just figured out the logged-in user's name, refesh.

		percent: (->
				current = @get 'current'
				total = @get 'total'
				percentage = 0
				if current and total
					percentage = Math.round (current / total) * 100
				'width: ' + percentage + '%;'
			).property 'current', 'total'
