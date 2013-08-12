module.exports = (Ember, App, socket) ->

	moment = require('moment')


	App.LeaderboardController = Ember.Controller.extend
		sortProperties: ['name']

	App.LeaderboardView = Ember.View.extend
		template: require '../../../templates/leaderboard'
		classNames: ['leaderboard']
		lowest: 0
		rankday: 'Sunday'
		fromdate: (->
			r = moment().day(@get('rankday'))
			if (r.unix() > moment().unix()) then r.subtract(7, 'days')
			r
		).property 'rankday'
		todate: (->
			r = moment().day(@get('rankday'))
			if (r.unix() <= moment().unix()) then r.add(7, 'days')
			r
		).property 'rankday'
		formattedfromdate: (->
			if @get('todate').toString().split(' ')[3] is @get('fromdate').toString().split(' ')[3] then ind=2
			else ind=3
			@get('fromdate').toString().split(' ')[0..ind].join(' ')
		).property 'todate', 'fromdate'
		formattedtodate: (->
			a = @get('todate').toString().split(' ')[1..3]
			a[1] = @get('todate').lang().ordinal(a[1])
			if @get('todate').toString().split(' ')[1] is @get('fromdate').toString().split(' ')[1] then a=a[1..]
			a.join(' ')
		).property 'todate', 'fromdate'

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

