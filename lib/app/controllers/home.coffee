module.exports = (Ember, App, socket) ->


	App.IndexController = Ember.Controller.extend
		andCounting: 0

	App.IndexView = Ember.View.extend
		template: require '../../../templates/home'
		classNames: ['home']
		didInsertElement: ()->
			socket.emit 'total.contacts', (results) =>
				if not results then return
				@set 'controller.andCounting', results
				formatthis = results
				format = ''
				while formatthis > 1
					format += '9'
					formatthis /= 10
				Ember.run.next this, ->
					@$('.counter').counter(
						initial: "0"
						direction: 'up',
						format: format,
						interval: 1,
						stop: "#{results}"
					).counter 'play'
