module.exports = (Ember, App) ->
	_ = require 'underscore'
	_str = require 'underscore.string'
	_.mixin _str.exports()
	moment = require 'moment'

	socketemit = require '../socketemit.coffee'

	searchPagePageSize = 10
	sortFieldNames = ['familiarity', 'reachability', 'names', 'added']

	App.ResultsController = Ember.ObjectController.extend
		searchtag:null
		sortType: null		# identify sorting rule
		sortDir: 0			# 1 if ascending, -1 if descending

		industryOp: 0	# boolean operation : or = 0, and = 1
		orgOp: 0

		f_knows: []
		f_indtags: []
		f_orgtags: []

		loseTag: ->
			@set 'searchtag', null
			newResults = App.Results.create {text: ''}
			App.Router.router.transitionTo "results", newResults

		orgTagsToSelect: (->
			toptags = []
			if tags = @get 'f_orgtags'
				for t in tags
					toptags.push { id:t, checked:false, label:_.prune _.capitalize(t), 20 }
			toptags
		).property 'f_orgtags'

		indTagsToSelect: (->
			toptags = []
			if tags = @get 'f_indtags'
				for t in tags
					toptags.push { id:t, checked:false, label:_.prune _.capitalize(t), 20 }
			toptags
		).property 'f_indtags'

		noseToPick: []
		pickTheNose: (->
			ids = @get 'f_knows'
			if ids?.length
				@store.filter('user', {_id:$in:ids}, (data)->
					_.contains ids, data.get('id')
				).then (gno)=>
					topnose = []
					gno.forEach (n)->
						if n.get('canonicalName')
							topnose.push { id:n.get('id'), checked:false, label:n.get('canonicalName') }
					@set 'noseToPick', topnose
		).observes 'f_knows'

		multiNose: (->
			@get('f_knows')?.length > 1
		).property 'f_knows'
		someFilter: (->
			@get('f_knows')?.length > 1 or @get('f_inidtags')?.length > 0 or @get('f_orgtags')?.length > 0
		).property 'f_knows', 'f_indtags', 'f_orgtags'

		all: []				# every last search result
		empty: false		# flag for empty results message
		initialflag: 0		# dont scroll on initial load

		buildFilter: ->
			emission = filter:@get('query')
			if @get 'datapoor' then emission.moreConditions = poor:true
			if (n2p = @get('noseToPick')) then for n in n2p
				if n.checked
					if not emission.knows then emission.knows = [n.id]
					else emission.knows.push n.id
			indTags = _.pluck _.filter(@get("indTagsToSelect"), (item)-> item and item.checked), 'id'
			if indTags?.length then emission.industry = indTags
			orgTags = _.pluck _.filter(@get("orgTagsToSelect"), (item)-> item and item.checked), 'id'
			if orgTags?.length then emission.organisation = orgTags
			if (d = @get 'sortDir')
				if d < 0 then emission.sort = "-#{@get('sortType')}"
				else emission.sort = @get('sortType')
			if @get('industryOp') then emission.indAND=true
			if @get('orgOp') then emission.orgAND=true
			emission

		previousPage: ->
			if (p = @get 'page')
				@set 'all', []
				p = p-1
				@set 'page', p
				emission = @buildFilter()
				emission.page = p
				@set 'empty', false
				socketemit.get 'fullSearch', emission, (results) =>
					if results?.response?.length
						@set 'all', @store.find 'contact', results.response
					else @set 'empty', true

		nextPage: ->
			p = @get('page')+1
			if p*searchPagePageSize < @get('filteredCount')
				@set 'all', []
				@set 'page', p
				emission = @buildFilter()
				emission.page = p
				@set 'empty', false
				socketemit.get 'fullSearch', emission, (results) =>
					if results?.response?.length
						@set 'all', @store.find 'contact', results.response
					else @set 'empty', true

		runFilter: ->
			emission = @buildFilter()
			if emission.knows?.length or emission.industry?.length or emission.organisation?.length or @get('totalCount') isnt @get('filteredCount')
				@set 'all', []
				@set 'page', 0
				@set 'empty', false
				socketemit.get 'fullSearch', emission, (results) =>
					if results?.response?.length
						@set 'all', @store.find 'contact', results.response
					else @set 'empty', true
					@set 'filteredCount', results?.filteredCount

		filterAgain:(->
			if @get('noseToPick')?.length then @runFilter()
		).observes 'noseToPick.@each.checked', 'indTagsToSelect.@each.checked', 'orgTagsToSelect.@each.checked'

		maybeRun: (prefix)->
			tags = _.filter @get("#{prefix}TagsToSelect"), (item)-> item and item.checked
			if tags?.length > 1
				if @get('all') and @get('totalCount') then @runFilter()

		refilterIfIndustryOpsMatter: (->
			@maybeRun 'ind'
		).observes 'industryOp'

		refilterIfOrgOpsMatter: (->
			@maybeRun 'org'
		).observes 'orgOp'

		sortAgain: ->
			if not @get('all') or not @get('totalCount') then return
			emission = @buildFilter()
			@set 'all', []
			@set 'page', 0
			@set 'empty', false
			socketemit.get 'fullSearch', emission, (results) =>
				if results?.response?.length
					@set 'all', @store.find 'contact', results.response
				else @set 'empty', true

		query:null				# query string
		page:0					# pagination
		totalCount:0			# unfiltered total
		filteredCount:0			# filtered total (showing filteredCount of totalCount)
		hiding: (->
			@get('totalCount') - @get('filteredCount')
		).property 'totalCount', 'filteredCount'
		rangeStart: (->
			@get('page')*searchPagePageSize
		).property 'page'
		rangeStop: (->
			stop = (@get('page')+1)*searchPagePageSize
			if stop > @get('filteredCount') then stop = @get('filteredCount')
			stop
		).property 'page', 'filteredCount'
		hasPrevious: (->
			@get 'page'
		).property 'page'
		hasNext: (->
			@get('rangeStop') < @get('filteredCount')
		).property 'rangeStop', 'filteredCount'
		paging: (->
			@get('hasPrevious') or @get('hasNext')
		).property 'hasPrevious', 'hasNext'
		theResults: (->		# paginated content
			a = @get 'all'
			if not a?.get('length') then return null
			a
		).property 'all.@each'

		scrollUp: (->
			rs = @get 'rangeStart'
			if @initialflag isnt rs
				@initialflag = rs
				$('html, body').animate {scrollTop: 0}, 666		# when the paginated content changes
		).observes 'rangeStart'

		userToggle: (id, name)->
			if not (n2p = @get('noseToPick')) then return
			for n in n2p
				if id is n.id then return Ember.set n, 'checked', not n.checked
			# new user, not listed, so add to list, and filter on this user only
			newnose = []
			for n in n2p
				newnose.push {id:n.id, checked:false, label:n.label}
			newnose.push { id:id, checked:true, label:_.prune _.capitalize(name), 20 }
			@set 'noseToPick', newnose

		tagToggle: (cat, bod)->
			if cat is 'industry' then prefix = 'ind'
			else prefix = 'org'
			tts = @get "#{prefix}TagsToSelect"
			if (t = _.find(tts, (item)-> item.id is bod))
				return Ember.set t, 'checked', not t.checked	# already in list? toggle and quit
			# new tag, not listed, so add to list, and filter on this tag only
			chckbxs = []
			for t in tts
				chckbxs.push { id:t.id, checked:false, label:t.label }
			chckbxs.push { id:bod, checked:true, label:_.prune _.capitalize(bod), 20 }
			@set "#{prefix}TagsToSelect", chckbxs


	App.ResultsView = Ember.View.extend
		classNames: ['results']
		storePriorTags: {}
		storePopTags: {}


	App.ResultController = App.ContactController.extend
		canHide: true


	App.ResultView = App.ContactView.extend

		clicktag: (ev)->
			if @get('parentView').controller.get('datapoor') then return
			@get('parentView').controller.tagToggle ev.get('category'), ev.get('body')
		clickname: (ev)->
			if @get('parentView').controller.get('datapoor') then return
			@get('parentView').controller.userToggle ev.get('id'), ev.get('name')

		didInsertElement: ()-> @get('controller').set 'showitall', false
		hideItAll: (r)-> r.set 'showitall', false
		setShowItAll: (r)->
			r.set 'showitall', true
			@get('controller').setHistories()
			@get('controller').getMeasures()

	App.SortView = Ember.View.extend
		template: require '../../../templates/components/sort.jade'
		classNames: ['sort']
		dir: (->
			if t = @get 'controller.sortType'
				if _.contains this.classNames, t
					return @get 'controller.sortDir'
			0
		).property 'controller.sortType', 'controller.sortDir'
		down: (-> 0 > @get 'dir').property 'dir'
		up: (-> 0 < @get 'dir').property 'dir'
		sort: (ascdesc) ->
			for i in sortFieldNames
				if _.contains this.classNames, i
					@set 'controller.sortType', i
					@set 'controller.sortDir', ascdesc
			false
		sorttoggle: () ->
			nowdir = @get('dir')
			if not nowdir
				for i in sortFieldNames
					if _.contains this.classNames, i
						@set 'controller.sortType', i
						@set 'controller.sortDir', -1
			else if thistype = @get 'controller.sortType'
				if _.contains this.classNames, thistype
					if nowdir<0 then newdir = 1
					else newdir = 0
					@set 'controller.sortDir', newdir
					if newdir is 0 and not @get('controller.query')
						@set 'controller.sortType', 'added'
						@set 'controller.sortDir', -1

			@get('controller').sortAgain()

		didInsertElement: ()->
			@$().parent().tooltip
				placement: 'bottom'
