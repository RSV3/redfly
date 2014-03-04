module.exports = (Ember, App) ->

	moment = require('moment')


	App.LeaderboardController = Ember.Controller.extend
		sortProperties: ['name']
		datapoor: 0

	App.LeaderboardView = Ember.View.extend
		template: require '../../../templates/leaderboard.jade'
		classNames: ['leaderboard']
		lowest: 0
		###
		# we used to have a weekly leaderboard, with a set day for resetting rank
		# now we use a 30-day sliding window
		rankday: 'Sunday'		# not really meaningful now that we use a sliding window rather than a cutoff day
		fromdate: (->
			r = moment().day(@get('rankday'))
			if (r.unix() > moment().unix()) then r.subtract(7, 'days')		
			r
		).property 'rankday'
		todate: (->
			# we used to have a weekly leaderboard, with a set day for resetting rank
			# now we use a 30-day sliding window
			r = moment().day(@get('rankday'))
			if (r.unix() <= moment().unix()) then r.add(7, 'days')
			r
		).property 'rankday'
		###
		fromdate: moment().subtract(30, 'days')
		todate: moment()
		formattedfromdate: (->
			if @get('todate').toString().split(' ')[3] is @get('fromdate').toString().split(' ')[3] then ind=2
			else ind=3
			@get('fromdate').toString().split(' ')[1..ind].join(' ')
		).property 'todate', 'fromdate'
		formattedtodate: (->
			a = @get('todate').toString().split(' ')[1..3]
			#a[1] = @get('todate').lang().ordinal(a[1])
			if @get('todate').toString().split(' ')[1] is @get('fromdate').toString().split(' ')[1] then a=a[1..]
			a.join(' ')
		).property 'todate', 'fromdate'

	App.LeadLagController = Ember.Controller.extend()

	App.LeadLagView = Ember.View.extend
		tagName: 'tr'
		idsme: (->
			App.user.get('id') is @get('content.id')
		).property('content.id')
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

