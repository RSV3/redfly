_ = require 'underscore'

module.exports = (Ember, App, socket) ->
	util = require '../../util'

	App.LinkerView = Ember.View.extend
		template: require '../../../../views/templates/components/linker'

		didInsertElement: ->
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
					# linker doesn't return any errors, this never happens
					return alert err.message + ' Are you connected to the internet? Did you allow access to LinkedIn?'
				@set 'stateConnecting', false
				@set 'stateParsing', false
				@set 'stateDone', true
				@get('notification').effect 'bounce'
				if changes
					changes = _.filter(changes, (c) -> App.store.recordIsLoaded(App.Contact, c))
					if changes.length
						App.adapter.findMany App.store, App.Contact, changes
				@get('notification').pnotify type: 'success', closer: true, hide: true

			socket.on 'link.total', (total) =>
				@set 'current', 0
				@set 'total', total
				@set 'stateConnecting', false
				@set 'stateParsing', true
				@set 'stateDone', false
				socket.on 'link.connection', =>
					@incrementProperty 'current'

		percent: (->
				current = @get 'current'
				total = @get 'total'
				percentage = 0
				if current and total
					percentage = Math.round (current / total) * 100
				'width: ' + percentage + '%;'
			).property 'current', 'total'
