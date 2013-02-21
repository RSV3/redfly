module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'

	App.ResultsController = Ember.ArrayController.extend App.Pagination,
		itemController: 'result'
		yearsToSelect: []
		tagsToSelect: []
		check: {}
		years: 0
		dir: null
		weightF: null
		results: null
		pluckedresults: null
		backupresults: null
		hiding: 0

		gottags: {}

		getTags: () ->
			o = {}
			toptags = []			# build a list of the most common tags to filter by
			newtags = []			# reduce the list of gottags to those used in filters
			if (oC = @results)
				contactIDs = _.pluck(oC.slice(0), 'id')

				@gottags = Ember.ArrayProxy.create 
					content: App.Tag.find({category: 'redstar', contact: $in: contactIDs})
				@gottags.addObserver('content.isLoaded', this, () ->
					tags = @gottags.slice(0)
					if tags.length
						for t in tags
							b = t.get 'body'
							if not o[b] then o[b]=1
							else o[b]++
						for t of o
							id = t
							lab = _s.capitalize(t)
							if lab.length > 40
								lab = lab.substr(0,40) + '...'
							toptags.push { chkboxdata: {id:id, checked:false, label:lab}, count: o[t] }
						toptags.sort((a,b) -> b.count - a.count)
						toptags = _.pluck toptags.slice(0,7), 'chkboxdata'

						tagnames = []
						for t in toptags
							tagnames.push t.id
						for t in tags
							if _.contains tagnames, t.get('body')
								newtags.push t
						@gottags = newtags

						@set 'tagsToSelect', toptags
						@set 'years', 0
						$('div.filters').show()
						search = App.get 'router.applicationView.spotlightSearchViewInstance.searchBoxViewInstance'
						if search
							search.set 'searching', false
				)

		maxyrs: ->
			my = 0
			if (res = @results)
				for i in res.slice 0
					if i.get('yearsExperience') > my
						my = i.get('yearsExperience')
			my

		content: (->
			if @results
				@results.addObserver('content.isLoaded', this, () ->
					max = @maxyrs()
					@set 'yearsToSelect', []
					if max
						for i in [max..1]
							@get('yearsToSelect').push Ember.Object.create({label: 'at least '+i+' years', years:i})
					@getTags()
					@set 'pluckedresults', @results.slice 0
					@set 'backupresults', @results.slice 0
					@set 'hiding', 0
				)
				Ember.ArrayProxy.create
					content: @results
		).property 'results'

		scrollUp: (->
			$('html, body').animate {scrollTop: 0}, 666
		).observes 'rangeStart'

		startplusone: (->
			1 + parseInt(@get('rangeStart'), 10)
		).property 'rangeStart'

		doSort: ( ->
			oC = @.get('pluckedresults').slice 0
			if oC isnt null
				if @backupresults
					@set 'hiding', @backupresults.length - @pluckedresults.length
				newC = oC.slice(0)
				if @dir and @weightF
					newC.sort((first,second) => @dir * (@weightF(first) - @weightF(second)))
				if newC.length isnt @results.length
					@set 'rangeStart', 0
				@set 'results', newC
		).observes 'pluckedresults', 'dir'

		###
		#TODO: I know this was very Wrong. I will change this to work The Ember Way.
		###
		sort: (ev) ->
			$t = $(ev.target)
			if $t.hasClass 'icon-2x'
				$t.removeClass 'icon-2x'
				$t.addClass 'icon-large'
				@set 'dir', 0
			else
				$('.sort .icon-2x').removeClass 'icon-2x'
				$t.addClass 'icon-2x'
				if $t.parent().parent().hasClass 'proximity'
					@weightF = (rec) ->
						if user is rec.get('addedBy') then return 2
						for user in rec.get('knows')
							if user is App.user.get('content') then return 1
						return 0
				else if $t.parent().parent().hasClass 'influence'
					@weightF = (rec) ->
						rec.get('knows.length')
				@set 'dir', (if $t.hasClass('icon-caret-up') then 1 else -1)

		tagFilter: (oldc, newc, filterF, finalF) ->
			if _.isEmpty oldc
				return finalF newc
			c = oldc.shift()
			if filterF(c) then newc.push c
			_.defer =>
				@tagFilter oldc, newc, filterF, finalF		# defer each contact to avoid compute bind

		setTags: (oC) ->
			filterTags = []
			for item in @get 'tagsToSelect'
				if item.checked
					filterTags.push item.id
			if oC and filterTags.length
				search = App.get 'router.applicationView.spotlightSearchViewInstance.searchBoxViewInstance'
				if search
					search.set 'searching', true
				newC = []
				oldC = oC.slice 0
				@tagFilter oldC, newC, (c) =>	# needed a defer-able async mechanism to avoid compute bound loop
					for t in @gottags
						if t.get('contact.id') is c.get('id') and  _.contains(filterTags, t.get('body'))
							return true
					return false
				, (newc) =>
					@set 'pluckedresults', newc
					if search
						search.set 'searching', false
			else
				@set 'pluckedresults', oC

		setYears: (oC) ->
			newC = []
			if oC and @years
				for c in oC
					if c.get('yearsExperience') >= @years
						newC.push c
			else
				newC = oC
			newC

		changeFilters: (->		# note: defer for prompt event feedback (checkbox tick)
				_.defer =>
					@setTags @setYears @backupresults.slice 0
				false
			).observes 'years', 'tagsToSelect.@each.checked'


	App.ResultsView = Ember.View.extend
		template: require '../../../templates/results'
		didInsertElement: ->
			$('div.filters').hide()

	App.ResultController = Ember.Controller.extend

	App.ResultView = Ember.View.extend App.SomeContactMethods,
		template: require '../../../templates/result'
		introView: App.IntroView
		socialView: App.SocialView
		classNames: ['contact']

