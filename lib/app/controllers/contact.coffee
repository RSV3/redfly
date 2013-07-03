module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../util'

	App.ContactController = Ember.ObjectController.extend App.ContactMixin,

		showEmail: (->
			a = App.Admin.find 1
			@get('isKnown') or a and not a.get('hidemails') or @get('forceShowEmail')
		).property 'id'
		allMeasures: (->
			if (id=@get('id'))
				App.Measurement.find contact:id
		).property 'id'
		waitingForMeasures: (->
			m = @get('allMeasures')
			not m or not m.get('isLoaded')
		).property 'allMeasures', 'allMeasures.@each'
		gotMeasures: (->
			@get('allMeasures')?.get 'length'
		).property 'allMeasures', 'allMeasures.@each'
		measures: (->
			measures = {}
			if @.get 'gotMeasures'
				allMs = @get 'allMeasures'
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
		knowsSome: (->
			fams = @get('measures.familiarity')
			if not fams or not fams.length then f = []
			else f = fams.getEach 'user'
			othernose = @get('knows')?.filter (k)-> not _.contains(f, k)
			_.uniq f.concat othernose
		).property 'knows', 'measures'

		editpositiondetails: (->
			if not (@get('position') or @get('company') or @get('yearsExperience'))
				"Edit details about #{@get('nickname')}'s professional experience"
		).property 'position', 'company', 'yearsExperience'
		###
		histories: (->
			# TODO Hack. If clause only here to make sure that all the mails don't get pulled down on "all done" classify page where the
			# fake contact is below the page break and has no ID set
			if not @get('id') then return []
			query = sender: App.user.get('id'), recipient: @get('id')
			App.filter App.Mail, {field: 'sent'}, query, (data) =>
				(data.get('sender.id') is App.user.get('id')) and (data.get('recipient.id') is @get('id'))
		).property 'id'
		###
		firstHistory: null
		lastHistory: null
		setHistories: (->
			if id=@get('id')
				@set 'firstHistory', App.findOne App.Mail, conditions:{sender:App.user.get('id'), recipient:id}, options:{sort:'date'}
				@set 'lastHistory', App.findOne App.Mail, conditions:{sender:App.user.get('id'), recipient:id}, options:{sort:'-date'}
		).observes 'id'
		spokenTwice: (->
			@get('lastHistory') and @get('firstHistory') and @get('lastHistory.id') isnt @get('firstHistory.id')
		).property 'lastHistory.id', 'firstHistory.id'
		firstTalked: (->
			if not sent = @get('firstHistory.sent') then return null
			moment = require 'moment'
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

		# emptyNotesText: (->
		# 		if _.random(1, 10) < 9
		# 			# return 'No notes about ' + @get('nickname') + ' yet.'	# TO-DO doesn't work? Something to do with volatile?
		# 			return 'No notes about this contact yet.'
		# 		('...and that\'s why you ' +
		# 			' <a href="http://www.dailymotion.com/video/xrjyfz_that-s-why-you-always-leave-a-note_shortfilms" target="_blank">' +
		# 			 'always leave a note!</a>'
		# 		).htmlSafe()
		# 	).property().volatile()

		add: ->
			if note = util.trim @get('currentNote')
				App.Note.createRecord
					date: new Date	# Only so that sorting is smooth.
					author: App.User.find App.user.get 'id'
					contact: @get 'content'
					body: note
				@set 'updated', new Date
				@set 'updatedBy', App.User.find App.user.get 'id'
				App.store.commit()
				@set 'animate', true
				@set 'currentNote', null
		toggleVIP: ->
			if @get 'isKnown'
				@set 'isVip', not @get 'isVip'
				@set 'updated', new Date
				@set 'updatedBy', App.user.get 'id'
				App.store.commit()
		dumpContact: ->
			@set 'knows.content', @get('knows').filter (u)-> u.get('id') isnt App.user.get('id')
			App.Exclude.createRecord user: App.user, contact: @get 'content'
			App.store.commit()
			@transitionToRoute "userProfile"


	App.ContactView = Ember.View.extend
		template: require '../../../templates/contact'
		classNames: ['contact']

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
			tags = @get 'tags'
			cattags =
				industry:[]
				project:[]
				role:[]
				theme:[]
			if not tags or not tags.get('length') then return cattags
			tags.forEach (t)->
				if (c = t.get('category'))
					if not cattags[c] then cattags[c]=[]
					cattags[c].push t
			cattags
		).property 'tags.@each'
		tags: (->
			if (id = @get('controller.id'))
				App.Tag.filter {contact: id}, (data) =>
					data.get('contact.id') is id
		).property 'controller.id'

		introMailto: (->
			CR = '%0D%0A'		# carriage return / line feed
			port = if window.location.port then ":#{window.location.port}" else ""
			url = "http://#{window.location.hostname}#{port}/contact/#{@get 'controller.id'}"
			$('p.bullhorn>a').css('color','grey').bind('click', false)
			socket.emit 'getIntro', {contact: @get('controller.id'), userto: @get('controller.addedBy.id'), userfrom: App.user.get('id'), url:url}, () =>
				$('p.bullhorn').replace("<p class='requestsent'>intro<br>request<br>sent</p>")
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
			template: require '../../../templates/components/edit'
			tagName: 'span'
			classNames: ['edit', 'overlay']
			primary: ((key, value) ->
				if arguments.length is 1
					return @get 'controller.' + @get('primaryAttribute')
				value
			# ).property 'controller.' + @get('primaryAttribute')
			# TODO hack
			).property 'controller.name', 'controller.email'
			others: (->
				Ember.ArrayProxy.create content: @_makeProxyArray @get('controller.' + @get('otherAttribute'))
			# ).property 'controller.' + @get('otherAttribute')
			# TODO hack
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
				if that.get('parentView')._makeProxyArray
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
						that.set 'controller.updated', new Date
						that.set 'controller.updatedBy', App.user.get 'id'
						App.store.commit()
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
				@set 'modal', $(@$('.modal')).modal()
			merge: ->
				@get('modal').modal 'hide'

				notification = util.notify
					title: 'Merge status'
					text: 'The merge is in progress. MEERRRGEEE.'
					type: 'info'
					hide: false
					closer: false
					sticker: false
					icon: 'icon-signin'
					before_open: (pnotify) =>
						pnotify.css top: '60px'

				selections = @get 'selections'
				socket.emit 'merge', contactId: @get('controller.id'), mergeIds: selections.getEach('id'), =>
					# Ideally we'd just unload the merged contacts from the store, but this functionality doesn't exist yet in ember-data.
					# Issue a delete instead even though they're already deleted in the database.
					selections.forEach (selection) -> selection.deleteRecord()
					App.store.commit()
					# Refresh the store with the stuff that could have changed.
					App.refresh @get('controller.content')
					App.Tag.find contact: @get('controller.id')
					App.Note.find contact: @get('controller.id')
					App.Mail.find recipient: @get('controller.id')

					notification.effect 'bounce'
					notification.pnotify
						text: "One #{@get 'controller.nickname'} to rule them all!"
						type: 'success'
						hide: true
						closer: true

				@get('selections').clear()


			mergeSearchView: App.SearchView.extend
				prefix: 'contact:'
				conditions: (->
					addedBy: App.user.get 'id'
					_id: {$ne: @get 'controller.id'}
				).property()
				excludes: (->
					@get('parentView.selections').toArray().concat @get('controller.content')
				).property 'controller.content', 'parentView.selections.@each'
				select: (context) ->
					@get('parentView.selections').pushObject context

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

		###
		# this is how we used to show measurements with a slider
		###
		###
		sliderView: Ember.View.extend
			tagName: 'div'
			classNames: ['contactslider']

			myMeasurements: (->
				@get('controller.measures')?[@get 'measure']?.filter((eachM)-> eachM.get('user.id') is App.user.get('id')) or []
			).property "controller.measures[controller.measure]"

			didInsertElement: ()->
				view = @
				@$().slider {
					value: _.first @get('myMeasurements').getEach 'value'
					min: -100
					step: 10
					animate: 'fast'
					change: (e, ui)=>
						Ember.run.next this, ()->
							allMs = view.get 'controller.measures'
							thism = view.get 'measure'
							if (m = allMs[thism]?.filter((eachM)-> eachM.get('user.id') is App.user.get('id')))
								m.get('firstObject').set 'value', ui.value
							else
								if not allMs[thism] then allMs[thism] = Ember.ArrayProxy.create content: []
								allMs[thism].pushObject App.Measurement.createRecord {
									user: App.user
									contact: view.get 'controller.content'
									attribute: view.get 'measure'
									value: ui.value
								}
							view.get('controller').notifyPropertyChange 'measures'
							App.store.commit()
						false
				}

		###

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
							if not allMs[thism] then allMs[thism] = Ember.ArrayProxy.create content: []
							allMs[thism].pushObject App.Measurement.createRecord {
								user: App.user
								contact: view.get 'controller.content'
								attribute: view.get 'measure'
								value: newvalue
							}
						view.set 'value', (newvalue+100)/40
						view.set 'controller.updated', new Date
						view.set 'controller.updatedBy', App.user
						App.store.commit()
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
						@.get('parentView').save()
				toggle: ->
					if not @toggleProperty('show')
						@get('controller').get('transaction').rollback()	# This probably could be better, only targeting changes to this contact.
				save: ->
					@set 'working', true
					@set 'controller.updated', new Date
					@set 'controller.updatedBy', App.user
					App.store.commit()
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
						if (value = @get('value')) and not value.match(util.socialPatterns[network])
							_s = require 'underscore.string'
							@set 'error', 'That doesn\'t look like a ' + _s.capitalize(network) + ' URL.'
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
						App.store.commit()
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
