module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'
	moment = require 'moment'


	doTags = (whichTags, context)->
		oT = context.get(whichTags)
		if not oT or not oT.get('length')
			return
		tags = _.countBy oT.getEach('body'), (item)-> item
		toptags = []
		for t of tags
			lab = _s.capitalize(t)
			if lab.length > 20 then lab = lab.substr(0,15) + '...'						# truncate long tags
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
		knoNames: []
		noseToPick: []
		all: []				# every last search result
		initialflag: 0		# dont scroll on initial load
		filteredItems: (->	# just the ones matching any checked items AND the specified minimum years
			if _.isEmpty (oC = @get('all')) then return []
			oC.filter (item) =>
				if @years and not (item.get('yearsExperience') >= @years)
					return false

				hasnose = found = false
				if (n2p = @get('noseToPick'))
					for n in n2p
						if n.checked
							hasnose = true
							if _.contains item.get('knows').getEach('id'), n.id
								found = true
				if hasnose and not found then return false

				noTags = true
				for prefix in ['org', 'ind']
					filterTags = _.pluck _.filter(@get("#{prefix}TagsToSelect"), (item)-> item and item.checked), 'id'
					if filterTags.length
						noTags = false
						for t in @get("#{prefix}TagsToConsider")
							if t.get('contact.id') is item.get('id') and _.contains filterTags, t.get('body')
								return true
				noTags
			).property 'all.@each', 'years', 'noseToPick.@each.checked', 'indTagsToSelect.@each.checked', 'orgTagsToSelect.@each.checked'

		theResults: (->		# paginated content
			if not @get 'filteredItems.length'
				@initialflag=0
				[]
			else Ember.ArrayProxy.createWithMixins App.Pagination,
				content: do =>
					@set 'hiding', @get('all.length') - @get('filteredItems.length')
					@set 'rangeStart', 0
					@get('showWhich')?.set 'showitall', false
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

		# oh, this was tricky:
		# in order to always get the knows array, had to watch on the @each (id/knows) of @each (knows/contacts)
		watchAllNoses:(->
				aC = @get('allThoseNoses')
				if not aC or not aC.length then return
				if not aC[0].get('length') then return
				results = []
				aC.forEach (c)->
					results.pushObjects c.getEach('id')
				nose = _.countBy results, (item)-> item
				topnose = []
				for k, v of nose
					if k and v then topnose.push {id:k, count:v}
				if topnose.length<2 then return						# no point having a filter for one user!
				ids = _.pluck _.sortBy(topnose, (n)-> -n.count)[0..7], 'id'
				@set 'knoNames', Ember.ArrayProxy.create
					content: App.User.find _id: $in: ids
		).observes 'allThoseNoses.@each.@each'

		setNoseTags: (->
			if not (kT = @get 'knoNames') then return
			if not kT.get 'length' then return
			topKnows = []
			kT.forEach (knows)->
				lab = _s.capitalize knows.get 'name'
				if lab.length > 20 then lab = lab.substr(0,20) + '...'						# truncate long tags
				if lab.length		# just in case of error
					topKnows.push { id:knows.get('id'), checked:false, label:lab }		# array of all checkboxes
			@set "noseToPick", topKnows		# array of top 'knows' users
		).observes 'knoNames.@each'

		setOrgTags: (->
			Ember.run.next this, ()->
				doTags 'orgTags', @
		).observes 'orgTags.@each'
		setIndTags: (->
			Ember.run.next this, ()->
				doTags 'indTags', @
		).observes 'indTags.@each'

		setFilters: (->			# prepare the filters based on the sort results
				years = []
				oC = @get('all')
				if not oC or not oC.get('length')
					@set 'indTagsToSelect', null
					@set 'orgTagsToSelect', null
					@set 'yearsToSelect', null
					@set 'noseToPick', null
					return		# don't bother if there's no data
				max = _.max(oC.getEach('yearsExperience'), (y)-> y or 0)
				if max > 0
					for i in [1..max]
						years.push Ember.Object.create(label: 'at least ' + i + ' years', years: i) 
				@set 'yearsToSelect', years
				@set 'orgTags', Ember.ArrayProxy.create
					content: App.Tag.find {category: {$ne: 'industry'}, contact: $in: oC.getEach('id')}
				@set 'indTags', Ember.ArrayProxy.create
					content: App.Tag.find {category: 'industry', contact: $in: oC.getEach('id')}

				@set 'allThoseNoses', oC.getEach('knows')
			).observes 'all.@each'

		maybeToggle: (bod)->
			for prefix in ['org', 'ind']
				if (t = _.find(@get("#{prefix}TagsToSelect"), (item)-> item.id is bod))
					Ember.set t, 'checked', not t.checked

	App.ResultsView = Ember.View.extend
		classNames: ['results']

	App.ResultController = App.ContactController.extend
		notes: (->
			query = contact: @get('id')
			App.filter App.Note, {field: 'date'}, query, (data) =>
				data.get('contact.id') is @get('id')
		).property 'id'
		lastNote: (->
			@get 'notes.lastObject'
		).property 'notes.lastObject'
		mails: (->
			query = recipient: @get('id')
			App.filter App.Mail, {field: 'sent'}, query, (data) =>
				data.get('recipient.id') is @get('id')
		).property 'id'
		lastMail: (->
			@get 'mails.lastObject'
		).property 'mails.lastObject'
		indTags: (->
			query = category:'industry', contact: @get('id')
			socket.emit 'tags.popular', query, (popularTags) =>
				result.pushObjects _.map popularTags[0..3], (t)->{body:t.body, category:t.category}
			result = []
		).property 'id'
		orgTags: (->
			query = category:{$in: ['theme', 'role', 'project']}, contact: @get('id')
			socket.emit 'tags.popular', query, (popularTags) =>
				result.pushObjects _.map popularTags, (t)->{body:t.body, category:t.category}
			result = []
		).property 'id'
		sentdate: (->
			moment(@get('lastMail.sent')).fromNow()
		).property 'lastMail'
		isKnown: (->
				@get('knows')?.find (user) ->
					user.get('id') is App.user.get('id')	# TO-DO maybe this can be just "user is App.user.get('content')"
			).property 'knows.@each.id'
		knowsSome: []
		setKS: (->
			fams = @get('measures.familiarity')
			if not fams or not fams.length then f = []
			else f = fams.getEach 'user'
			othernose = @get('knows')?.filter (k)-> not _.contains(f, k)	# prioritse most familiar
			f = _.uniq f.concat othernose									# then add on other known users
			f = _.reject f, (u)-> u.get('id') is App.user.get('id')		# don't list self in knowsSome list
			if f and f.length then @set 'knowsSome', f
		).observes 'knows.@each', 'measures.familiarity.@each'


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

	App.ResultView = App.ContactView.extend
		clicktag: (ev)->
			@get('parentView').controller.maybeToggle ev.body

		setShowItAll: (r)->
			if (old = @get 'parentView.controller.showWhich')
				old.set 'showitall', false
			@get('parentView.controller.showWhich')?.set 'showitall', false
			@set 'parentView.controller.showWhich', r
			r.set 'showitall', true

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
			for i of sortFields
				if _.contains this.classNames, i
					@set 'controller.sortType', i
					@set 'controller.sortDir', ascdesc
			false
		sortdesc: () ->
			if @get('dir') is 0 then @sort -1
			else if @get('dir') is 1 then @sort 0
		sortasc: () ->
			if @get('dir') is 0 then @sort 1
			else if @get('dir') is -1 then @sort 0

		didInsertElement: ()->
			@$().parent().tooltip
				placement: 'bottom'
