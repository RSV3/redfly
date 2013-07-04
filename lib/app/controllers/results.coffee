module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_str = require 'underscore.string'
	_.mixin(_str.exports());
	moment = require 'moment'

	searchPagePageSize = 25
	sortFieldNames = ['influence', 'proximity', 'names', 'added']

	App.ResultsController = Ember.ObjectController.extend
		hiding: 0			# this is just for templating, whether or not results are filtered out
		sortType: null		# identify sorting rule
		sortDir: 0			# 1 if ascending, -1 if descending


		f_knows: []
		f_industry: []
		f_organisation: []

		loseTag: ->
			@set 'searchtag', null
			newResults = App.Results.create {text: 'contact:0'}
			App.Router.router.transitionTo "results", newResults

		othersorts: (->
			return @get('totalCount')<99
		).property 'totalCount'

		orgTagsToSelect: (->
			tags = @get 'f_organisation'
			toptags = []
			for t in tags
				toptags.push { id:t, checked:false, label:_.prune _.capitalize(t), 20 }
			toptags
		).property 'f_organisation'

		indTagsToSelect: (->
			tags = @get 'f_industry'
			toptags = []
			for t in tags
				toptags.push { id:t, checked:false, label:_.prune _.capitalize(t), 20 }
			toptags
		).property 'f_industry'

		noseToPick: (->
			topnose = []
			gno = @get('known')
			if gno?.get('length') is @get('f_knows.length')
				gno.forEach (n)->
					topnose.push { id:n.get('id'), checked:false, label:n.get('canonicalName') }
			topnose
		).property 'known.@each.isLoaded'

		known: (->
			ids = @get('f_knows')
			App.User.find {_id:$in:ids}
			App.User.filter (data) =>
				_.contains ids, data.get('id')
		).property 'f_knows'

		all: []				# every last search result
		initialflag: 0		# dont scroll on initial load

		buildFilter: ->
			emission = filter:@get('query')
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
			emission

		previousPage: ->
			if (p = @get 'page')
				@set 'all', []
				p = p-1
				@set 'page', p
				emission = @buildFilter()
				emission.page = p
				socket.emit 'fullSearch', emission, (results) =>
					if results?.response?.length
						@set 'all', App.store.findMany(App.Contact, results.response)
					else @set 'all', null

		nextPage: ->
			p = @get('page')+1
			if p*searchPagePageSize < @get('filteredCount')
				@set 'all', []
				@set 'page', p
				emission = @buildFilter()
				emission.page = p
				socket.emit 'fullSearch', emission, (results) =>
					if results?.response?.length
						@set 'all', App.store.findMany(App.Contact, results.response)
					else @set 'all', null

		filterAgain:(->
			if not @get('all') or not @get('totalCount') then return

			emission = @buildFilter()
			if emission.knows?.length or emission.industry?.length or emission.organisation?.length or @get('totalCount') isnt @get('filteredCount')
				@set 'all', []
				@set 'page', 0
				socket.emit 'fullSearch', emission, (results) =>
					if results?.response?.length
						@set 'all', App.store.findMany(App.Contact, results.response)
					else @set 'all', null
					@set 'filteredCount', results?.filteredCount
		).observes 'noseToPick.@each.checked', 'indTagsToSelect.@each.checked', 'orgTagsToSelect.@each.checked'

		sortAgain: ->
			if not @get('all') or not @get('totalCount') then return
			emission = @buildFilter()
			@set 'all', []
			@set 'page', 0
			socket.emit 'fullSearch', emission, (results) =>
				if results?.response?.length
					@set 'all', App.store.findMany(App.Contact, results.response)
				else @set 'all', null
				#).observes 'sortDir', 'sortType'

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
			if not a?.get('length') then null
			else a
		).property 'all'

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


	App.ResultController = App.ContactController.extend
		canHide: true
		knowsSome: []
		setKS: (->
			if (f = @get('knows'))
				if f.get('length') then @set 'knowsSome', f
		).observes 'knows.@each.isLoaded'


	App.ResultView = App.ContactView.extend

		clicktag: (ev)->
			@get('parentView').controller.tagToggle ev.get('category'), ev.get('body')
		clickname: (ev)->
			@get('parentView').controller.userToggle ev.get('id'), ev.get('name')

		didInsertElement: ()->
			@get('controller').set 'showitall', false
		hideItAll: (r)->
			if (old = @get 'parentView.controller.showWhich')
				old.set 'showitall', false
		setShowItAll: (r)->
			@hideItAll()
			@get('parentView.controller.showWhich')?.set 'showitall', false
			@set 'parentView.controller.showWhich', r
			r.set 'showitall', true
			that = this

	App.SortView = Ember.View.extend
		template: require '../../../templates/components/sort'
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
			nudir = 0
			if thistype = @get 'controller.sortType'
				if _.contains this.classNames, thistype
					nudir = -1*@get('dir')
			if not nudir
				for i in sortFieldNames
					if _.contains this.classNames, i
						@set 'controller.sortType', i
				nudir = 1
			@set 'controller.sortDir', nudir
			@get('controller').sortAgain()

		###
		sortdesc: () ->
			if @get('dir') is 0 then @sort -1
			else if @get('dir') is 1 then @sort 0
		sortasc: () ->
			if @get('dir') is 0 then @sort 1
			else if @get('dir') is -1 then @sort 0
		###

		didInsertElement: ()->
			@$().parent().tooltip
				placement: 'bottom'
