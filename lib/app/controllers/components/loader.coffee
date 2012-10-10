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

			# TODO
			# manager = Ember.StateManager.create
			# 	start: Ember.State.create()
			# 	parsing: Ember.State.create()
			# 	end: Ember.State.create()

			@set 'stateConnecting', true

			socket.emit 'parse', App.user.get('id'), (message) =>
				# TODO check if 'message' param exists, if so there was an error. Can also do error as a custom event if necessary. The alert is a
				# temporary mesasure
				if message
					alert message + ' Are you connected to the internet? Did you mistype your email?'
				else
					@get('loading').effect 'bounce'
					@get('loading').pnotify type: 'success', closer: true
					App.refresh App.user.get('content')	# Classify queue has been determined and saved on the server, refresh the user.	# TODO try without .get('content')
					@set 'stateDone', true
					@set 'stateParsing', false

			socket.on 'parse.total', (total) =>
				@set 'current', 0
				@set 'total', total
				@set 'stateParsing', true
				@set 'stateConnecting', false
			socket.on 'parse.name', =>
				App.refresh App.user.get('content')	# We just figured out the logged-in user's name, refesh.
			socket.on 'parse.update', =>
				@incrementProperty 'current'

		percent: (->
				current = @get 'current'
				total = @get 'total'
				percentage = 0
				if current and total
					percentage = Math.round (current / total) * 100
				'width: ' + percentage + '%;'
			).property 'current', 'total'
