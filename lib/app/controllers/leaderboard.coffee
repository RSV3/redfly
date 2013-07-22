module.exports = (Ember, App, socket) ->

	moment = require('moment')


	App.LeaderboardController = Ember.Controller.extend
		sortProperties: ['name']
		fromdate: moment().day(-2).format("MMMM DD, YYYY")
		todate: moment().day(4).format("MMMM DD, YYYY")

	App.LeaderboardView = Ember.View.extend
		template: require '../../../templates/leaderboard'
		classNames: ['leaderboard']
		lowest: 0

	App.LeadLagController = Ember.Controller.extend()

	App.LeadLagView = Ember.View.extend
		tagName: 'tr'
		change: (->
			@get('pos') - (@get('content.lastRank') or @get('parentView.controller.lowest'))
		).property 'pos', 'content.lastRank'
		down: (->
			@get('change') > 0
		).property 'change'
		up: (->
			@get('change') < 0
		).property 'change'
		changeText: (->
			ch = @get('change')
			if ch == 0 then 'stable'
			else if ch > 0 then "(-#{ch})"
			else if ch < 0 then "(+#{-ch})"
			else ""
		).property 'change'

	App.LeaderView = App.LeadLagView.extend
		pos: (->
			@get('contentIndex') + 1
		).property()

	App.LaggardView = App.LeadLagView.extend
		pos: (->
			#@get('parentView.controller.lowest') - @get('contentIndex') 
			# TODO: little hack, might need better way to make it correct
			if @get('parentView.controller.lowest') > 4
				@get('parentView.controller.lowest') - (4 - @get('contentIndex'))
			else
				@get('contentIndex') + 1
		).property()

