module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../util.coffee'
	moment = require 'moment'

	App.ContactController = Ember.ObjectController.extend

		hovering: null
		allowEdits: (->
			if @get('isKnown') then return true
			a = @store.find 'admin', 1
			a and a.get('anyedit') isnt false
		).property 'id'
		isKnown: (->
			u = App.user.get 'id'
			k = @get('knows')?.getEach 'id'
			@get('addedBy.id') is u or k and _.contains k, u
		).property 'addedBy', 'knows.@each.id'

		noneButIAdded: (->
			not @get('addedBy') or App.user.get('id') is @get('addedBy.id')				# no-one added, or I added
		).property 'addedBy'

		hasIntro: (->
			@get('addedBy') and not @get('isKnown')
		).property 'addedBy', 'isKnown'	# someone added, and I don't know

		gmailSearch: (->
				encodeURI "//gmail.com#search/to:#{@get('email')}"
			).property 'email'
		directMailto: (->
				"mailto:#{@get('canonicalName')}<#{@get('email')}>?subject=What are the haps my friend!"
			).property 'canonicalName', 'email'
		linkedinMail: (->
				'//www.linkedin.com/requestList?displayProposal=&destID=' + @get('linkedin') + '&creationType=DC'
			).property 'linkedin'
		waitingForMeasures:true
		allMeasures:null
		getMeasures: (->
			@store.find('measurement', contact:@get('id')).then (ms)=>
				@set 'waitingForMeasures', false
				@set 'allMeasures', ms
		).observes 'id'
		###
		waitingForMeasures: (->
			m = @get('allMeasures')
			not m or not m.get('isLoaded')
		).property 'allMeasures', 'allMeasures.@each'
		###
		gotMeasures: (->
			not @get('waitingForMeasures') and @get('allMeasures')?.get 'length'
		).property 'waitingForMeasures', 'allMeasures.@each'
		measures: (->
			measures = {}
			if @.get 'gotMeasures'
				@get('allMeasures').then (allMs)->
					atts = _.uniq allMs.getEach 'attribute'
					for eachAt in atts
						measures[eachAt] = _.sortBy(allMs.filter((m)-> m.get('attribute') is eachAt), (eachM)-> -eachM.get('value'))
			measures
		).property 'gotMeasures', 'allMeasures.@each'
		averages: (->
			averages = {}
			measures = @get 'measures'
			for eachAt of measures
				if measures[eachAt].length
					averages[eachAt] = (_.reduce measures[eachAt].getEach('value'), (memo, v)-> memo+v) / measures[eachAt].length or 1	# better not to have zero average
			averages
		).property 'measures', 'measures.@each'

		knowsSome: null
		setKS: (->
			@get('knows').then (docs)=>
				if docs.get('length') then @set 'knowsSome', docs
		).observes 'knows.@each'


		editpositiondetails: (->
			if not (@get('position') or @get('company') or @get('yearsExperience'))
				"Edit details about #{@get('nickname')}'s professional experience"
		).property 'position', 'company', 'yearsExperience'
		firstHistory: null
		lastHistory: null
		lastNote: null
		sentdate: (->
			moment(@get('lastHistory.sent')).fromNow()
		).property 'lastHistory'
		setHistories: (->
			if id=@get('id')
				@store.find('mail', {conditions:{sender:App.user.get('id'), recipient:id}, options:{sort:{sent:1},limit:1}}).then (mails)=>
					@set 'firstHistory', mails.content[0]
				@store.find('mail', {conditions:{sender:App.user.get('id'), recipient:id}, options:{sort:{sent:-1},limit:1}}).then (mails)=>
					@set 'lastHistory', mails.content[0]
				@store.find('note', {conditions:{contact:id}, options:{sort:{date:-1},limit:1}}).then (notes)=>
					@set 'lastNote', notes.content[0]
		).observes 'id'
		spokenTwice: (->
			@get('lastHistory') and @get('firstHistory') and @get('lastHistory.id') isnt @get('firstHistory.id')
		).property 'lastHistory.id', 'firstHistory.id'
		firstTalked: (->
			if not sent = @get('firstHistory.sent') then return null
			moment(sent).fromNow()
		).property 'firstHistory.sent'
		lastTalked: (->
			if not sent = @get('lastHistory.sent') then return null
			moment = require 'moment'
			moment(sent).fromNow()
		).property 'lastHistory.sent'
		disableAdd: (->
			not util.trim @get('currentNote')
		).property 'currentNote'

		add: ->
			if note = util.trim @get('currentNote')
				@store.createRecord 'note',
					date: new Date	# Only so that sorting is smooth.
					author: App.user
					contact: @get 'content'
					body: note
				@commitNcount()
				@set 'animate', true
				@set 'currentNote', null
		toggleVIP: ->
			if @get 'isKnown'
				@set 'isVip', not @get 'isVip'
				@commitNcount()

		remove: ->
			knows = @get('knows').then (ids)->
				_.filter ids, (u)-> u.id isnt App.user.get('id')
			ab = @get('addedBy') 
			if ab?.get('id') is App.user.get('id')
				if knows.length then ab = knows[0]
				else ab = null
				@set 'addedBy', ab
			@set 'knows.content', knows
			if not ab then @set 'added', null
			@store.createRecord 'exclude',
				user: App.user
				contact: @store.find 'contact', @get 'id'
			@commitNcount()

		commitNcount: ->
			@set 'updated', new Date
			@set 'updatedBy', App.user
			@save()

		getExtensionData: (ev)->
			if not ev then return
			if url = ev.publicProfileUrl
				tmpSocV = App.SocialView.create()
				patternName = tmpSocV.guessPattern 'linkedin', url
				url = tmpSocV.simplifyID patternName, url
				if url.match(util.socialPatterns[patternName])
					@set 'linkedin', url
			if url = ev.pictureUrl and not @get('picture') then @set 'picture', ev.pictureUrl
			if name = ev.name
				if not @get('names')?.length or @get('names').length is 1 and @get('name') is @get('desperateName')
					@set 'names', [ev.name]
				else @set 'names', @get('names').unshift ev.name
			if ev.companies.length and not @get('company') then @set 'company', ev.companies[0]
			if ev.positions.length and not @get('position') then @set 'position', ev.positions[0]
			for spec in ev.specialties
				if spec and not _.contains @get('indTags'), spec
					@store.createRecord 'tag', {
					    date: new Date  # Only so that sorting is smooth.
						creator: App.user
						contact: this.store.find 'contact', @get 'id'
						category: 'industry'
						body: spec
					}
			@set 'updated', new Date
			@set 'updatedBy', App.user
			@save()


	App.ContactuserView = App.HoveruserView.extend
		template: require '../../../templates/components/contactuser.jade'

	App.ContactView = Ember.View.extend
		template: require '../../../templates/contact.jade'
		classNames: ['contact']

		showEmail: (->
			c = @get('controller')
			c.store.find('admin', 1).then (a)=>
				c.get('isKnown') or a and a.get('hidemails') is false or @get('parentView.classifying')
		).property 'id'
		indTags: (->
			@get('catTags')?['industry']
		).property 'catTags'
		orgTags: (->
			result = []
			if not (ct = @get('catTags')) then return result
			for own key, val of ct
				if key not in ['industry', 'organisation'] then result = result.concat val
			result
		).property 'catTags'
		catTags: (->
			cattags = industry:[]
			if not (cats = App.admin.get 'orgtagcats')
				return console.log "ERROR: no admin categories ..."
			_.each _.map(cats.split(','), (t)-> t.trim()), (t)->
				cattags[t] = []	# add empty list for each organisational tag category
			tags = @get 'tags'
			if not tags or not tags.get('length') then return cattags
			tags.forEach (t)->
				if (c = t.get('category'))
					if not cattags[c] then cattags[c]=[]
					cattags[c].push t
			cattags
		).property 'tags.@each', 'App.admin.orgtagcats'
		tags: (->
			c = @get 'controller'
			id = c.get 'id'
			c.store.filter 'tag', {contact: id}, (data) ->
				id and data.get('contact.id') is id
		).property 'controller.id'

		introMailto: (->
			bootbox.confirm "Request an introduction from #{@get 'controller.addedBy.name'}?", (yorn)=>
				if not yorn then return
				CR = '%0D%0A'		# carriage return / linefeed
				port = if window.location.port then ":#{window.location.port}" else ""
				url = "http://#{window.location.hostname}#{port}/contact/#{@get 'controller.id'}"
				$('p.bullhorn>a').css('color','grey').bind('click', false)
				socket.emit 'getIntro', {contact: @get('controller.id'), userto: @get('controller.addedBy.id'), userfrom: App.user.get('id'), url:url}, () =>
					util.notify
						title: 'Introduction requested'
						text: '<div id="requestintro"></div>'
						type: 'success'
						closer: true
						sticker: false
						hide: false
						effect: 'bounce'
						before_open: (pnotify) =>
							pnotify.css top: '60px'

		)

		vipHoverStr: ->
			if @get 'controller.isVip'
				"Clear this contact's VIP status"
			else
				"Mark #{@get 'controller.nickname'} as a VIP"
		changeVipHoverStr: (->
			@get('tooltip')?.data('tooltip')?.options?.title = @vipHoverStr()
		).observes 'controller.isVip'
		didInsertElement: ->
			if @get 'controller.isKnown'
				@set 'tooltip', @$('div.maybevip').tooltip
					title: @vipHoverStr()
					placement: 'left'
				@$('span.dumpcontact').tooltip
					title: "Permanently exclude #{@get 'controller.nickname'}"
					placement: 'bottom'
				@$('h4.email').tooltip
					title: "send a message to #{@get 'controller.nickname'}"
					placement: 'bottom'

		showMerge: ->
			@get('mergeViewInstance')._launch()

		editView: Ember.View.extend
			template: require '../../../templates/components/edit.jade'
			tagName: 'span'
			classNames: ['edit', 'overlay']
			primary: ((key, value) ->
				if arguments.length is 1
					return @get 'controller.' + @get('primaryAttribute')
				value
			).property 'controller.name', 'controller.email'
			others: (->
				Ember.ArrayProxy.create content: @_makeProxyArray @get('controller.' + @get('otherAttribute'))
			).property 'controller.aliases', 'controller.otherEmails'
			_makeProxyArray: (array) ->
				# Since I can't bind to positions in an array, I have to create object proxies for each of the elements and add/remove those.
				_.map array, (value) ->
					Ember.ObjectProxy.create content: value
			toggle: ->
				@toggleProperty 'show'
			add: ->
				@get('others').pushObject Ember.ObjectProxy.create content: ''
				_.defer =>   # TO-DO Ember.run.next is equivalent but would be semantically more appropriate.
					# Ideally there's a way to get a list of itemViews and pick the last one, and not do this with jquery.
					@$('input').last().focus()

			save: ->
				# now, here's an ugly way to check the context.
				# If we get here because of the newlinebinding on the undefined textobject,
				# the context will be the embertextview - so step up one level.
				that = @
				if that.get('parentView.parentView')?._makeProxyArray
					that = that.get('parentView.parentView')	# ugly context test.
				else if that.get('parentView')?._makeProxyArray
					that = that.get('parentView')	# ugly context test.
				that.set 'working', true

				all = that.get('others')?.getEach('content') or []
				all.unshift that.get('primary')
				all = _.compact _.map all, (item)-> util.trim item

				nothing = _.isEmpty all
				that.set 'nothing', nothing

				# Set primary and others to the new values so the user can see any modifications to the input while stuff saves.
				that.set 'primary', _.first all
				that.set 'others.content', that._makeProxyArray _.rest all
				socket.emit 'deprecatedVerifyUniqueness', id: that.get('controller.id'), field: that.get('allAttribute'), candidates: all, (duplicate) ->
					that.set 'duplicate', duplicate

					if (not nothing) and (not duplicate)
						that.set "controller.#{that.get('allAttribute')}", all
						that.get("controller").commitNcount()
						that.toggle()
					that.set 'working', false

			initiateMerge: ->
				@toggle()
				@get('parentView').showMerge()


			itemView: Ember.View.extend
				classNames: ['row-fluid']
				primaryBinding: 'parentView.primary'
				othersBinding: 'parentView.others'
				promote: ->
					el = @$().parent().find('input:first')
					primary = @get 'primary'
					promoted = @get 'other.content'
					@set 'primary', promoted
					# Not sure why defer makes this work.
					_.defer =>
						@get('others').removeObject @get('other')
						@get('others').unshiftObject Ember.ObjectProxy.create content: primary
						$(el).focus()
				remove: ->
					@get('others').removeObject @get('other')

		mergeView: Ember.View.extend
			classNames: ['merge']
			selections: (->
				Ember.ArrayProxy.create content: []
			).property 'controller.content'
			_launch: ->
				@get('selections').clear()
				@set 'modal', $(@$('.modal')).modal()
			merge: ->
				store = @get('controller').store
				notification = util.notify
					title: 'Merge status'
					text: 'The merge is in progress. MEERRRGEEE.'
					type: 'info', icon: 'icon-signin'
					hide: false, closer: false, sticker: false
					before_open: (pnotify) =>
						pnotify.css top: '60px'

				selections = @get 'selections'
				id = @get 'controller.id'
				socket.emit 'merge', contactId:id, mergeIds: selections.getEach('id'), (mergedcontact)=>
					# doing this for now because the deleterec (below) doesn't work. maybe remove this line after EPF upgrade?
					if not @get('parentView.parentView.classifying') then window.location.reload()

					# Refresh the store with the stuff that could have changed.
					for own key,val of mergedcontact
						if key is 'addedBy' then @set 'controller.addedBy', App.user
						else if key is 'knows'
							@set 'controller.knows', _.map val, (v)-> store.find 'user', v
						else @set "controller.#{key}", val
					store.find 'tag', contact: id
					store.find 'note', contact: id
					store.find 'mail', recipient: id

					# Ideally we'd just unload the merged contacts from the store, but this functionality doesn't exist yet in ember-data.
					# Issue a delete instead even though they're already deleted in the database.
					###
					# I think this error will be fixed by EPF upgrade??
					while selections.get 'length'
						sel = selections.popObject()
						console.log "deleting"
						console.dir sel
						try
							sel?.deleteRecord()
						catch err
							console.log "deleting record after merge..."
							console.dir err
					###
					@get('selections').clear()

					@save()

					notification.effect 'bounce'
					notification.pnotify
						text: "One #{@get 'controller.nickname'} to rule them all!"
						type: 'success'
						hide: true
						closer: true
					@get('modal').modal 'hide'


			mergeSearchView: App.SearchView.extend
				prefix: 'contact:'
				conditions: (->
					addedBy: App.user.get 'id'
					_id: $ne: @get('controller.id')
				).property()
				excludes: (->
					@get('parentView.selections').getEach('id').concat @get('controller.id')
				).property 'controller.content', 'parentView.selections.@each'
				select: (context) ->
					store = @get('controller').store
					$('div.search.dropdown').blur()
					@get('parentView.selections').addObject store.find 'contact', context.id
				# override form submission
				keyUp: (event) -> false
				submit: -> false

		measureBarView: Ember.View.extend
			tagName: 'div'
			classNames: ['contactbar']

			avgMeasure: (->
				@get("controller.averages")[@get 'measure']
			).property "controller.averages.@each"
			widthAsPcage: (->
				v = @get('avgMeasure')/2
				if v<0 then v = -v
				"width:#{v}%"
			).property 'avgMeasure'
			ltORgtClass: (->
				if @get('avgMeasure') > 0 then return 'gtzbarview'
				else return 'ltzbarview'
			).property 'avgMeasure'

			upBarView: Ember.View.extend
				classNames: ['gtzbarview']

			downBarView: Ember.View.extend
				classNames: ['ltzbarview']

		starView: Ember.View.extend
			tagName: 'p'
			classNames: ['contactstars']
			value: (->
				mm = @get('controller.measures')?[@get 'measure']?.filter((eachM)-> eachM.get('user.id') is App.user.get('id')) or []
				if mm and mm.length
					(_.first(mm.getEach 'value') + 100)/40
				else -1
			).property "controller.measures.@each"
			_drawStars: (->
				v = @get 'value'
				@$().find('i').each (index)->
					if index < v
						$(this).addClass('icon-star').removeClass('tmpstar hoverstar icon-star-empty')
					else
						$(this).addClass('icon-star-empty').removeClass('tmpstar hoverstar icon-star')
				false
			).observes 'value'
			didInsertElement: ()->
				view = @
				store = @get('parentView.controller').store
				for i in [0...5]
					@$().append($newstar=$("<i>"))
					$newstar.addClass("icon-large starcount#{i}")
					$newstar.hover ->
						posval = -1
						starclasses = $(this).attr('class').split(' ')
						for sc in starclasses
							if sc.substr(0,9) is 'starcount'
								posval = parseInt(sc.substr(9),10)
						$(this).parent().find('i').each (index)->
							if index is posval and view.get('value') is posval+1
								$(this).addClass('tmpstar hoverstar icon-star-empty').removeClass('icon-star')
							else if index <= posval
								$(this).addClass 'hoverstar'
					, ->
						$(this).parent().find('i').removeClass 'hoverstar'
						$(this).parent().find('i.tmpstar').addClass('icon-star').removeClass('icon-star-empty')
					$newstar.click ->
						allMs = view.get 'controller.measures'
						thism = view.get 'measure'
						oldval = view.get 'value'
						posval = -1
						starclasses = $(this).attr('class').split(' ')
						for sc in starclasses
							if sc.substr(0,9) is 'starcount'
								posval = parseInt(sc.substr(9),10)
						if posval+1 is oldval then posval--
						newvalue = (posval+1)*40 - 100

						if (m = allMs[thism]?.find((eachM)-> eachM.get('user.id') is App.user.get('id')))
							m.set 'value', newvalue
						else
							newm = store.createRecord 'measurement', {
								user: App.user
								contact: view.get 'controller.content'
								attribute: view.get 'measure'
								value: newvalue
							}
							newm.save().then ->
								if not allMs[thism] then allMs[thism] = Ember.ArrayProxy.create content: []
								allMs[thism].pushObject newm
								view.set 'value', (newvalue+100)/40
								view.set 'controller.updated', new Date
								view.set 'controller.updatedBy', App.user
								@get('controller.content').save()
								view._drawStars()
								view.get('controller').notifyPropertyChange 'measures'
				@_drawStars()
				@$().parent().parent().tooltip
					placement: 'bottom'

		positionView: Ember.View.extend
			editView: Ember.View.extend
				tagName: 'span'
				classNames: ['overlay', 'edit-position']
				field: Ember.TextField.extend
					insertNewline: ->
						@get('parentView').save()
				toggle: ->
					if not @toggleProperty('show')
						@get('controller').get('transaction').rollback()	# This probably could be better, only targeting changes to this contact.
				save: ->
					@set 'working', true
					@set 'controller.updated', new Date
					@set 'controller.updatedBy', App.user
					@get('controller.content').save()
					@toggleProperty 'show'
					@set 'working', false

		socialView: App.SocialView.extend
			editView: Ember.View.extend
				tagName: 'span'
				classNames: ['overlay', 'edit-social']
				prefixesBinding: 'parentView.prefixes'

				field: Ember.TextField.extend
					focusIn: ->
						@set 'error', null
					focusOut: ->
						@_fire()
					insertNewline: ->
						@_fire()
					_fire: ->
						@set 'error', null
						network = @get 'network'
						if value = @get('value')
							socialView = @get 'parentView.parentView'
							patternName = socialView.guessPattern network, value
							value = socialView.simplifyID patternName, value
							if value.match(util.socialPatterns[patternName])
								@set 'value', value
							else
								_s = require 'underscore.string'
								@set 'error', "That doesn't look like a #{_s.capitalize network} URL."
				toggle: ->
					if not @toggleProperty('show')
						@get('controller').get('transaction').rollback()	# This probably could be better, only targeting changes to this contact.
				save: ->
					@set 'working', true
					for field in ['linkedinFieldInstance', 'twitterFieldInstance', 'facebookFieldInstance']
						@get(field)._fire()
					if not (@get('linkedinFieldInstance.error') or @get('twitterFieldInstance.error') or @get('facebookFieldInstance.error'))
						@set 'controller.updated', new Date
						@set 'controller.updatedBy', App.user
						@get('controller.content').save()
						@toggleProperty 'show'
					@set 'working', false

		newNoteView: Ember.TextArea.extend
			classNames: ['span12']
			attributeBindings: ['placeholder', 'rows', 'tabindex']
			placeholder: (->
				'Tell a story about ' + @get('controller.nickname') + ', describe a secret talent, whatever!'
			).property 'controller.nickname'
			rows: 3
			tabindex: 3
