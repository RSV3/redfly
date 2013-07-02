module.exports = (Ember, App, socket) ->


	App.LeaderboardController = Ember.Controller.extend
		sortProperties: ['name']

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
			@get('contentIndex')
		).property()

