module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'

	App.ResultsController = Ember.ArrayController.extend App.Pagination,
		itemController: 'result'
		itemsPerPage: 3
		content: []
		yearsToSelect: []
		tagsToSelect: []
		check: {}
		years: 0
		unfilteredContent: null

		###
		#TODO: I know this was very Wrong. I will change this to work The Ember Way.
		###
		doSort: (dir, weightF) ->
			if (oC = @get 'fullContent.content')
				newC = oC.slice(0)
				if dir and weightF
					newC.sort((first,second) -> dir * (weightF(first) - weightF(second)))
				@set 'fullContent.content', newC
				@set('rangeStart', @get('total')+1)

		sort: (ev) ->
			$t = $(ev.target)
			if $t.hasClass 'icon-2x'
				$t.removeClass 'icon-2x'
				$t.addClass 'icon-large'
				@doSort 0
			else
				$('.sort .icon-2x').removeClass 'icon-2x'
				$t.addClass 'icon-2x'
				if $t.parent().parent().hasClass 'proximity'
					weightF = (rec) ->
						if user is rec.get('addedBy') then return 2
						for user in rec.get('knows')
							if user is App.user.get('content') then return 1
						return 0
				else if $t.parent().parent().hasClass 'influence'
					weightF = (rec) ->
						rec.get('knows.length')
				@doSort (if $t.hasClass('icon-caret-up') then 1 else -1), weightF



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
				return newC
			else
				return oC

		gottags: {}

		getTags: () ->
			o = {}
			toptags = []
			if (oC = @unfilteredContent)
				contactIDs = _.pluck(oC, 'id')

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
							toptags.push { chkboxdata: {id:t.split(' ')[0], checked:false, label:_s.capitalize(t)}, count: o[t] }
						toptags.sort((a,b) -> b.count - a.count)
						toptags = _.pluck toptags.slice(0,7), 'chkboxdata'
						@set 'tagsToSelect', toptags
				)


		setYears: (oC) ->
			newC = []
			if oC and @years
				for c in oC
					if c.get('yearsExperience') >= @years
						newC.push c
				return newC
			else
				return oC

		changeFilters: (->
				if newC = @setYears @unfilteredContent
					newC = @setTags newC
					@set 'fullContent.content', newC
					@set('rangeStart', 0)
			).observes 'years', 'tagsToSelect.@each.checked'

		maxyrs: ->
			my = 0
			if (oC = @unfilteredContent)
				for i in oC 
					if i.get('yearsExperience') > my
						my = i.get('yearsExperience')
			my

		initPage: (->
			if _.isEmpty @unfilteredContent
				@unfilteredContent = @get('fullContent')?.get('content')?.slice(0)
				if _.isEmpty @unfilteredContent then return
				max = @maxyrs()
				@set 'yearsToSelect', []
				if max
					for i in [max..1]
						@get('yearsToSelect').push Ember.Object.create({label: 'at least '+i+' years', years:i})
				@getTags()
				$f = $('.search-filter')
				$f.css {opacity:1}
				$f.animate {marginLeft:"0"}, 666
			).observes 'total'

	App.ResultsView = Ember.View.extend
		template: require '../../../views/templates/results'
		didInsertElement: ->
			this.set 'controller.unfilteredContent', []	# new search, start afresh

	App.ResultController = Ember.Controller.extend

	App.ResultView = Ember.View.extend App.SomeContactMethods,
		template: require '../../../views/templates/result'
		introView: App.IntroView
		socialView: App.SocialView
		classNames: ['contact']

