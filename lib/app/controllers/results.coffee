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
			if lab.length > 20 then lab = lab.substr(0,20) + '...'						# truncate long tags
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

	App.ResultsController = Ember.ObjectController.extend
		hiding: 0			# this is just for templating, whether or not results are filtered out
		sortType: null		# identify sorting rule
		sortDir: 0			# 1 if ascending, -1 if descending
		years: 0			# value of selection from 'years experience' drop down
		yearsToSelect: []	# array of years from 1..max
		indTags: []			# all industry tags in the search
		indToSelect: []		# the short list of checkboxes for industry tags
		indToConsider: []	# the list of tags matching contacts in the results list & checkbox tagnames 
		orgTags: []
		orgToSelect: []
		orgToConsider: []
		all: []				# every last search result
		initialflag: 0		# dont scroll on initial load
		filteredItems: (->	# just the ones matching any checked items AND the specified minimum years
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

		theResults: (->		# paginated content
			if not @get 'filteredItems.length'
				@initialflag=0
				[]
			else Ember.ArrayProxy.createWithMixins App.Pagination,
				content: do =>
					@set 'hiding', @get('all.length') - @get('filteredItems.length')
					@set 'rangeStart', 0
					if @get 'sortType'
						Ember.ArrayController.create
							content: @get 'filteredItems'
							sortProperties: [sortFields[@get 'sortType']]
							sortAscending: @get('sortDir') is 1
							orderBy: sortFunc[@get 'sortType']
					else
						@get 'filteredItems'
		).property 'filteredItems.@each', 'sortType', 'sortDir'

		scrollUp: (->
			rs = @get 'theResults.rangeStart'
			if @initialflag isnt rs
				@initialflag = rs
				$('html, body').animate {scrollTop: 0}, 666		# when the paginated content changes
		).observes 'theResults.rangeStart'

		setOrgTags: (->
			doTags 'orgTags', @
		).observes 'orgTags.@each'
		setIndTags: (->
			doTags 'indTags', @
		).observes 'indTags.@each'
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
					content: App.Tag.find {category: {$ne: 'industry'}, contact: $in: oC.getEach('id')}
				@set 'indTags', Ember.ArrayProxy.create
					content: App.Tag.find {category: 'industry', contact: $in: oC.getEach('id')}
			).observes 'all.@each'

		toggleind: ()-> toggleFilter 'ind'		# toggle visbility of the industry tags
		toggleorg: ()-> toggleFilter 'org'		# toggle visbility of the organisational tags


	App.ResultsView = Ember.View.extend
		classNames: ['results']

	App.ResultController = Ember.ObjectController.extend App.ContactMixin,
		isKnown: (->
				@get('knows')?.find (user) ->
					user.get('id') is App.user.get('id')	# TO-DO maybe this can be just "user is App.user.get('content')"
			).property 'knows.@each.id'
		gmailSearch: (->
				encodeURI '//gmail.com#search/to:' + @get('email')
			).property 'email'
		directMailto: (->
				'mailto:'+ @get('canonicalName') + ' <' + @get('email') + '>' + '?subject=What are the haps my friend!'
			).property 'canonicalName', 'email'
		hasIntro: (->
				@get('addedBy') and not @get('isKnown')		#and @get('addedBy.email') 
			).property 'addedBy'
		introMailto: (->
				carriage = '%0D%0A'
				baseUrl = 'http://' + window.location.hostname + (window.location.port and ":" + window.location.port)
				url = baseUrl + '/contact/' + @get 'id'
				'mailto:' + @get('addedBy.canonicalName') + ' <' + @get('addedBy.email') + '>' +
					'?subject=You know ' + @get('nickname') + ', right?' +
					'&body=Hey ' + @get('addedBy.nickname') + ', would you kindly give me an intro to ' + @get('canonicalName') + '? ' +
					'This fella right here:' + carriage + carriage + encodeURI(url) +
					carriage + carriage + 'Your servant,' + carriage + App.user.get('nickname')
			).property 'nickname', 'canonicalName', 'addedBy.canonicalName', 'addedBy.email', 'addedBy.nickname'
		linkedinMail: (->
				'http://www.linkedin.com/requestList?displayProposal=&destID=' + @get('linkedin') + '&creationType=DC'
			).property 'linkedin'


	App.SortView = Ember.View.extend
		template: require '../../../templates/components/sort'
		classNames: ['sort']
		dir: (->
			for i of sortFields
				if _.contains this.classNames, i
					if i is @get 'controller.sortType'
						return @get 'controller.sortDir'
					return 0
			0
		).property 'controller.sortType', 'controller.sortDir'
		down: (-> 0 > @get 'dir').property 'dir'
		up: (-> 0 < @get 'dir').property 'dir'
		sort: (ascdesc) ->
			if ascdesc is @get 'dir'
				@set 'controller.sortDir', 0	# reset
			else 
				for i of sortFields
					if _.contains this.classNames, i
						@set 'controller.sortType', i
						@set 'controller.sortDir', ascdesc
			false
		sortdesc: () -> @sort -1
		sortasc: () -> @sort 1

