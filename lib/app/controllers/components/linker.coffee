_ = require 'underscore'

module.exports = (Ember, App, socket) ->
	util = require '../../util'

	App.LinkerView = Ember.View.extend
		template: require '../../../../templates/components/linker'
		classNames:['linker']

		didInsertElement: ->
			@set 'stateConnecting', true
			@set 'stateParsing', false
			@set 'stateDone', false
			@set 'stateThrottled', false

			@set 'notification', util.notify
				title: 'LinkedIn parsing status'
				text: '<div id="linking"></div>'
				type: 'info'
				hide: false
				closer: false
				sticker: false
				icon: 'icon-linkedin-sign'
				before_open: (pnotify) =>
					pnotify.css top: '60px'
					@$('#linkingStarted').appendTo '#linking'


			socket.emit 'linkin', App.user.get('id'), (err) =>
				if err
					@set 'stateThrottled', true
					@set 'stateDone', false
				else
					@set 'stateDone', true
					@set 'stateThrottled', false
				@set 'stateConnecting', false
				@set 'stateParsing', false
				@get('notification').effect 'bounce'
				@get('notification').pnotify type: 'success', closer: true, hide: true

			socket.on 'link.total', (total) =>
				@set 'current', 0
				@set 'current2', 0
				@set 'total', total
				@set 'stateConnecting', false
				@set 'stateParsing', true
				@set 'stateDone', false
				@set 'stateThrottled', false
				socket.on 'link.linkedin', =>
					@incrementProperty 'current2'
					current = @get 'current2'
					total = @get 'total'
				socket.on 'link.contact', =>
					@incrementProperty 'current'
					current = @get 'current'
					total = @get 'total'

		percent2: (->
				current = @get 'current2'
				total = @get 'total'
				percentage = 0
				if current and total
					percentage = Math.round (current / total) * 100
				'width: ' + percentage + '%;'
			).property 'current2', 'total'

		percent: (->
				current = @get 'current'
				total = @get 'total'
				percentage = 0
				if current and total
					percentage = Math.round (current / total) * 100
				'width: ' + percentage + '%;'
			).property 'current', 'total'
