_ = require 'underscore'

module.exports = (Ember, App) ->
	util = require '../../util.coffee'
	socketemit = require '../../socketemit.coffee'

	App.LinkerView = Ember.View.extend
		template: require '../../../../templates/components/linker.jade'
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
				icon: 'fa-linkedin-square'
				before_open: (pnotify) =>
					pnotify.css top: '60px'
					@$('#linkingStarted').appendTo '#linking'


			socketemit.get "linkin/#{App.user.get('id')}", (err) =>
				if err
					@set 'stateThrottled', true
					@set 'stateDone', false
				else
					@set 'stateDone', false
					@set 'stateDoneAndDone', true
				@set 'stateConnecting', false
				@set 'stateParsing', false
				@get('notification').effect 'bounce'
				@get('notification').pnotify
					type: 'success'
					closer: true
					hide: true

			###
			# we need to quickly find a better way to do this ...
			#
			#socket.on 'link.total', (total) =>
				@set 'current', 0
				@set 'current2', 0
				@set 'total', total
				@set 'stateConnecting', false
				@set 'stateParsing', true
				@set 'stateDone', false
				@set 'stateThrottled', false
				#socket.on 'link.linkedin', =>
					@incrementProperty 'current2'
				#socket.on 'link.contact', =>
					@incrementProperty 'current'
			###

		percent2: (->
			current2 = @get 'current2'
			total = @get 'total'
			percentage = 0
			if current2 and total
				percentage = Math.round (current2*100 / total)
				if current2 is total
					@set 'stateDone', true
			"width: #{percentage}%;"
		).property 'current2', 'total'

		percent: (->
			current = @get 'current'
			total = @get 'total'
			percentage = 0
			if current and total
				percentage = Math.round (current*100 / total)
			"width: #{percentage}%;"
		).property 'current', 'total'

