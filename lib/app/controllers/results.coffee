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

		gottags: {}

		getTags: () ->
			o = {}
			toptags = []
			if (oC = @results)
				contactIDs = _.pluck(oC.slice(0), 'id')

				gottags = Ember.ArrayProxy.create 
					content: App.Tag.find(contact: $in: contactIDs)
				gottags.addObserver('content.isLoaded', this, () ->
					tags = gottags.get('content').slice(0)
					if tags.length
						for t in tags
							if t.get('category') is 'redstar'
								b = t.get 'body'
								if not o[b] then o[b]=1
								else o[b]++
						for t of o
							id = t.split(' ')[0]
							lab = _s.capitalize(t)
							if lab.length > 40
								lab = lab.substr(0,40) + '...'
							toptags.push { chkboxdata: {id:id, checked:false, label:lab}, count: o[t] }
						toptags.sort((a,b) -> b.count - a.count)
						toptags = _.pluck toptags.slice(0,7), 'chkboxdata'
						@set 'tagsToSelect', toptags
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
					@.set 'pluckedresults', @results.slice 0
					@.set 'backupresults', @results.slice 0
				)
				Ember.ArrayProxy.create
					content: @results
		).property 'results'

		doSort: ( ->
			oC = @.get('pluckedresults').slice 0
			if oC isnt null
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

		setTags: (oC) ->
			filterTags = []
			for item in @get 'tagsToSelect'
				if item.checked
					filterTags.push item.label
			if oC and filterTags.length
				newC = []
				for c in oC
					tags = App.filter App.Tag, {field:'date'}, {category: 'redstar', contact:c.get('id')}, (m,x,e) ->
						m.get('contact.id') is c.get('id') and m.get('category') is 'redstar' and _.contains(filterTags, _s.capitalize(m.get('body')))
					if tags.get 'length'
						newC.push c
			else
				newC = oC
			newC

		setYears: (oC) ->
			newC = []
			if oC and @years
				for c in oC
					if c.get('yearsExperience') >= @years
						newC.push c
			else
				newC = oC
			newC

		changeFilters: (->
				_.defer =>
					@set 'pluckedresults', @setTags @setYears @backupresults.slice 0
			).observes 'years', 'tagsToSelect.@each.checked'


	App.ResultsView = Ember.View.extend
		template: require '../../../templates/results'

	App.ResultController = Ember.Controller.extend

	App.ResultView = Ember.View.extend App.SomeContactMethods,
		template: require '../../../templates/result'
		introView: App.IntroView
		socialView: App.SocialView
		classNames: ['contact']

