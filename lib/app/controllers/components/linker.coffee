module.exports = (Ember, App, socket) ->
	util = require '../../util'


	App.LinkerView = Ember.View.extend
		template: require '../../../../views/templates/components/linker'

		didInsertElement: ->
			@set 'modal', $(@$()).modal()	# TO-DO when fixing this, also check out the contacts merge modal
			@set 'notification', util.notify
				title: 'Link parsing status'
				text: '<div id="loading"></div>'
				type: 'info'
				hide: false
				closer: false
				sticker: false
				icon: 'icon-envelope'
				before_open: (pnotify) =>
					pnotify.css top: '60px'
					@$('#linkingStarted').appendTo '#loading'

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

			socket.emit 'linkin', App.user.get('id'), (err) =>
				# TODO check if 'err' param exists, if so there was an error. Can also do error as a custom event if necessary. The alert is a
				# temporary mesasure
				if err
					return alert err.message + ' Are you connected to the internet? Did you mistype your email?'
				@set 'stateConnecting', false
				@set 'stateParsing', false
				@set 'stateQueueing', false
				@set 'stateDone', true
				@get('notification').effect 'bounce'
				@get('notification').pnotify type: 'success', closer: true
				@get('modal').modal 'hide'

			socket.on 'parse.total', (total) =>
				@set 'current', 0
				@set 'total', total
				socket.on 'parse.mail', =>
					@incrementProperty 'current'
				@set 'stateConnecting', false
				@set 'stateParsing', true
				@set 'stateQueueing', false
				@set 'stateDone', false


		percent: (->
				current = @get 'current'
				total = @get 'total'
				percentage = 0
				if current and total
					percentage = Math.round (current / total) * 100
				'width: ' + percentage + '%;'
			).property 'current', 'total'

