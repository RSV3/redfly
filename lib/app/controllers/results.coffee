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
			if lab.length > 30 then lab = lab.substr(0,30) + '...'						# truncate long tags
			toptags.push { data: {id:t, checked:false, label:lab}, count: tags[t] }		# array of all checkboxes
		tts = _.pluck toptags.sort((a,b) -> b.count - a.count).slice(0,7), 'data'		# and this one's for krz
		tagnames = _.pluck tts, 'id'
		context.set "#{whichTags}ToSelect", tts	# array of top checkboxes
		context.set "#{whichTags}ToConsider", oT.filter (tag)=> _.contains tagnames, tag.get 'body'	# the Tags to keep track of

	sortFields =
		influence: 'knows.length'
		proximity: 'knows addedBy'

	sortFunc =
		influence: (v, w)->
			value = (v.get('knows.length') - w.get('knows.length'))
			if (@get 'sortAscending')
				return -value
			value
		proximity: (v, w)->
			value = (v.get('addedBy.id') is App.user.get('id')) - (w.get('addedBy.id') is App.user.get('id'))
			if not value
				value = _.contains(v.get('knows').getEach('id'), App.user.get('id')) - _.contains(w.get('knows').getEach('id'), App.user.get('id'))
			if (@get 'sortAscending')
				return -value
			value

	App.ResultsController = Ember.ArrayController.extend App.Pagination,
		itemController: 'result'
		sortType: null
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
				if @get 'sortType'
					Ember.ArrayController.create
						content: @get 'filteredItems'
						sortProperties: [sortFields[@get 'sortType']]
						sortAscending: @get 'sortDir'
						orderBy: sortFunc[@get 'sortType']
				else
					@get 'filteredItems'
			).property 'filteredItems.@each', 'sortType', 'sortDir'

		scrollUp: (->
			$('html, body').animate {scrollTop: 0}, 666
		).observes 'rangeStart'

		setFilters: (->			# prepare the filters based on the sort results
				years = []
				oC = @get('all')
				if not oC or not oC.get('length') then return		# don't bother if there's no data
				max = _.max(oC.getEach('yearsExperience'), (y)-> y or 0)
				if max > 0
					for i in [1..max]
						years.push Ember.Object.create(label: 'at least ' + i + ' years', years: i) 
				@set 'yearsToSelect', years
				@set 'orgTags', Ember.ArrayProxy.create
					content: App.Tag.find {category: 'redstar', contact: $in: oC.getEach('id')}
				@set 'indTags', Ember.ArrayProxy.create
					content: App.Tag.find {category: 'industry', contact: $in: oC.getEach('id')}
			).observes 'all.@each'

	 	setOrgTags: (->
				doTags 'orgTags', @
			).observes 'orgTags.@each'
	 	setIndTags: (->
				doTags 'indTags', @
			).observes 'indTags.@each'

		startplusone: (->							# this won't be necessary after the ember upgrade
			1 + parseInt(@get('rangeStart'), 10)	# when we can make this a boundhelper
		).property 'rangeStart'

		toggleind: ()-> toggleFilter 'ind'		# toggle visbility of the industry tags
		toggleorg: ()-> toggleFilter 'org'		# toggle visbility of the organisational tags

		sort: (ev)->
			resetting = $(ev.target).hasClass 'icon-large'				# krz won't like this,
			$('.icon-large').removeClass 'icon-large'					# I decided this was more succinct
			if not resetting then $(ev.target).addClass 'icon-large'

			dir = ($(ev.target).hasClass 'up')							# OK, no more jquery: state is on controller
			type = $(ev.target).parent().attr 'class'
			if @.get('sortDir') is dir and @.get('sortType') is type then type = null	# undo current sort option
			@.set 'sortType', type
			@.set 'sortDir', dir


	App.ResultsView = Ember.View.extend
		template: require '../../../templates/results'
		classNames: ['results']
		resultView: Ember.View.extend App.ContactMixin

