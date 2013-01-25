module.exports = (Ember, App, socket) ->
	util = require '../../util'

	App.LinkerView = Ember.View.extend
		template: require '../../../../views/templates/components/linker'

		didInsertElement: ->
			@set 'modal', $(@$()).modal()	# TO-DO when fixing this, also check out the contacts merge modal
			@set 'stateConnecting', true
			@set 'stateParsing', false
			@set 'stateDone', false

			@set 'notification', util.notify
				title: 'LinkedIn parsing status'
				text: '<div id="loading"></div>'
				type: 'info'
				hide: false
				closer: false
				sticker: false
				icon: 'icon-linkedin-sign'
				before_open: (pnotify) =>
					pnotify.css top: '60px'
					@$('#linkingStarted').appendTo '#loading'

			socket.emit 'linkin', App.user.get('id'), (err) =>
				if err
					return alert err.message + 'Are you connected to the internet? Did you allow access to LinkedIn?'
				@set 'stateConnecting', false
				@set 'stateParsing', false
				@set 'stateDone', true
				@get('notification').effect 'bounce'
				@get('notification').pnotify type: 'success', closer: true
				@get('modal').modal 'hide'

			socket.on 'parse.total', (total) =>
				@set 'current', 0
				@set 'total', total
				@set 'stateConnecting', false
				@set 'stateParsing', true
				@set 'stateDone', false
				socket.on 'parse.mail', =>
					@incrementProperty 'current'

		percent: (->
				current = @get 'current'
				total = @get 'total'
				percentage = 0
				if current and total
					percentage = Math.round (current / total) * 100
				'width: ' + percentage + '%;'
			).property 'current', 'total'


		profile: ->
			@get('modal').modal 'hide'
			@get('notification').pnotify_remove()
			
			App.get('router').send 'goUserProfile'
