module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'

	toggleFilter = (which)->
		$("i.toggle#{which}").toggleClass 'icon-caret-up icon-caret-down'
		$d = $("div.toggle#{which}")
		if ($d.toggleClass 'collapsed').hasClass 'collapsed' then $d.hide() else $d.show()

	doTags = (whichTags, context)->
		oT = context.get(whichTags)
		if not oT or not oT.get('length')
			return
		tags = _.countBy oT.getEach('body'), (item)-> item
		toptags = []
		for t of tags
			lab = _s.capitalize(t)
			if lab.length > 30
				lab = lab.substr(0,30) + '...'
			toptags.push { data: {id:t, checked:false, label:lab}, count: tags[t] }
		tts = _.pluck toptags.sort((a,b) -> b.count - a.count).slice(0,7), 'data' # this one's for krz
		tagnames = _.pluck tts, 'id'
		context.set "#{whichTags}ToSelect", tts
		context.set "#{whichTags}ToConsider", oT.filter (tag)=> _.contains tagnames, tag.get 'body'

	App.ResultController = Ember.ObjectController.extend
		sortByProximity: (->
			if App.user is rec.get('addedBy') then return 2
			for user in rec.get('knows')
				if user is App.user.get('content') then return 1
		).property 'addedBy', 'knows'

		sortByInfluence: (->
			@get 'knows.length'
		).property 'knows'

	App.ResultsController = Ember.ArrayController.extend App.Pagination,

		itemController: App.ResultController
		sortField: ''
		filteredItems: (->
				if _.isEmpty (oC = @get('all'))
					return []
				oC.filter (item) =>
					if @years and not (item.get('yearsExperience') >= @years)
						return false
					noTags = true
					for prefix in ['org', 'ind']
						filterTags = _.pluck _.filter(@get("#{prefix}TagsToSelect"), (item)-> item and item.checked), 'id'
						if filterTags.length
							noTags = false
							for t in @get("#{prefix}TagsToConsider")
								if t.get('contact.id') is item.get('id') and _.contains filterTags, t.get('body')
									return true
					noTags
			).property 'all.@each', 'years', 'indTagsToSelect.@each.checked', 'orgTagsToSelect.@each.checked'
		hiding: 0
		content: (->
				@set 'hiding', @get('all.length') - @get('filteredItems.length')
				@set 'rangeStart', 0
				Ember.ArrayProxy.create Ember.SortableMixin,
					content: @get 'filteredItems'
					sortProperties: [@get 'sortField']
					sortAscending: @get 'sortDir'
			).property 'filteredItems.@each', 'sortField'

		scrollUp: (->
			$('html, body').animate {scrollTop: 0}, 666
		).observes 'rangeStart'

		setFilters: (->
				years = []
				oC = @get('all')
				if not oC or not oC.get('length')
					return
				max = _.max(oC.getEach('yearsExperience'), (y)-> y or 0)
				if max > 0
					for i in [1..max]
						years.push Ember.Object.create(label: 'at least ' + i + ' years', years: i) 
				@set 'yearsToSelect', years
				@set 'orgTags', Ember.ArrayProxy.create
					content: App.Tag.find {category: 'redstar', contact: $in: oC.getEach('id')}
				@set 'indTags', Ember.ArrayProxy.create
					content: App.Tag.find {category: 'industry', contact: $in: oC.getEach('id')}
			).observes 'all.isLoaded'

	 	setOrgTags: (->
				doTags 'orgTags', @
			).observes 'orgTags.@each.isLoaded'
	 	setIndTags: (->
				doTags 'indTags', @
			).observes 'indTags.@each.isLoaded'

		startplusone: (->
			1 + parseInt(@get('rangeStart'), 10)
		).property 'rangeStart'

		toggleind: ()->
			toggleFilter 'ind'

		toggleorg: ()->
			toggleFilter 'org'

		sort: (ev)->
			dir = ($(ev.target).parent().hasClass 'up')
			field = $(ev.target).parent().parent().attr 'id'
			if @.get('sortDir') is dir and @.get('sortField') is field
				@.set 'sortField', ''
			else
				@.set 'sortDir', dir
				@.set 'sortField', field

		# 	###
		# 	#TODO: I know this was very Wrong. I will change this to work The Ember Way.
		# 	###
		# 	sort: (ev) ->
		# 		$t = $(ev.target)
		# 		if $t.hasClass 'icon-2x'
		# 			$t.removeClass 'icon-2x'
		# 			$t.addClass 'icon-large'
		# 			@set 'dir', 0
		# 		else
		# 			$('.sort .icon-2x').removeClass 'icon-2x'
		# 			$t.addClass 'icon-2x'
		# 			if $t.parent().parent().hasClass 'proximity'
		# 				@weightF = (rec) ->
		# 					if user is rec.get('addedBy') then return 2
		# 					for user in rec.get('knows')
		# 						if user is App.user.get('content') then return 1
		# 					return 0
		# 			else if $t.parent().parent().hasClass 'influence'
		# 				@weightF = (rec) ->
		# 					rec.get('knows.length')
		# 			@set 'dir', (if $t.hasClass('icon-caret-up') then 1 else -1)


		# doSort: ( ->
		# 	oC = @.get('pluckedresults').slice 0
		# 	if oC isnt null
		# 		newC = oC.slice(0)
		# 		if @dir and @weightF
		# 			newC.sort((first,second) => @dir * (@weightF(first) - @weightF(second)))
		# 		if newC.length isnt @results.length
		# 			@set 'rangeStart', 0
		# 		@set 'results', newC
		# ).observes 'pluckedresults', 'dir'




	App.ResultsView = Ember.View.extend
		template: require '../../../templates/results'
		classNames: ['results']

		resultView: Ember.View.extend App.ContactMixin

