module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../util'



	App.ContactController = Ember.ObjectController.extend
		histories: (->
				# TODO Hack. If clause only here to make sure that all the mails don't get pulled down on "all done" classify page where the
				# fake contact is below the page break and has no ID set
				if not @get('id')
					return []
				query = sender: App.user.get('id'), recipient: @get('id')
				App.filter App.Mail, {field: 'sent'}, query, (data) =>
					(data.get('sender.id') is App.user.get('id')) and (data.get('recipient.id') is @get('id'))
			).property 'id'
		firstHistory: (->
				@get 'histories.firstObject'
			).property 'histories.firstObject'
		lastTalked: (->
				if sent = @get('histories.lastObject.sent')
					moment = require 'moment'
					moment(sent).fromNow()
			).property 'histories.lastObject.sent'
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
					author: App.user
					contact: @get 'content'
					body: note
				App.store.commit()
				@set 'animate', true
				@set 'currentNote', null


	App.ContactView = Ember.View.extend App.SomeContactMethods,
		template: require '../../../views/templates/contact'
		classNames: ['contact']

		showMerge: ->
			@get('mergeViewInstance')._launch()

		editView: Ember.View.extend
			template: require '../../../views/templates/components/edit'
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
				_.defer =>
					# Ideally there's a way to get a list of itemViews and pick the last one, and not do this with jquery.
					@$('input').last().focus()
			save: ->
				@set 'working', true

				all = @get('others').getEach 'content'
				all.unshift @get('primary')
				all = _.chain(all)
					.map (item) ->
						util.trim item
					.compact()
					.value()

				nothing = _.isEmpty all
				@set 'nothing', nothing

				# Set primary and others to the new values so the user can see any modifications to the input while stuff saves.
				@set 'primary', _.first all
				@set 'others.content', @_makeProxyArray _.rest all
				socket.emit 'deprecatedVerifyUniqueness', @get('controller.id'), @get('allAttribute'), all, (duplicate) =>
					@set 'duplicate', duplicate

					if (not nothing) and (not duplicate)
						@set 'controller.' + @get('allAttribute'), all
						App.store.commit()
						@toggle()
					@set 'working', false
			initiateMerge: ->
				@toggle()
				@get('parentView').showMerge()
				

			itemView: Ember.View.extend
				classNames: ['row-fluid']
				primaryBinding: 'parentView.primary'
				othersBinding: 'parentView.others'
				promote: ->
					primary = @get 'primary'
					promoted = @get 'other.content'
					@set 'primary', promoted
					# Not sure why defer makes this work.
					_.defer =>
						@get('others').removeObject @get('other')
						@get('others').unshiftObject Ember.ObjectProxy.create content: primary
				remove: (event) ->
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
					# Ideally we'd just unload the merged contacts from the store, but this functionality doesn't exist yet in ember-data. Issue
					# a delete instead even though they're already deleted in the database.
					selections.forEach (selection) ->
						selection.deleteRecord()
					App.store.commit()
					# Refresh the store with the stuff that could have changed.
					App.refresh @get('controller.content')
					App.Tag.find contact: @get('controller.id')
					App.Note.find contact: @get('controller.id')
					App.Mail.find recipient: @get('controller.id')

					notification.effect 'bounce'
					notification.pnotify
						text: 'One ' + @get('controller.nickname') + ' to rule them all!'
						type: 'success'
						hide: true
						closer: true

				@get('selections').clear()


			mergeSearchView: App.SearchView.extend
				conditions: (->
						addedBy: App.user.get('id')
					).property()
				excludes: (->
						@get('parentView.selections').toArray().concat @get('controller.content')
					).property 'controller.content', 'parentView.selections.@each'
				select: (event) ->
					@get('parentView.selections').pushObject event.context

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
					_fire: ->
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
						App.store.commit()
						@toggleProperty 'show'
					@set 'working', false


		noteView: App.NoteView

		introView: App.IntroView

		newNoteView: Ember.TextArea.extend
			classNames: ['span12']
			attributeBindings: ['placeholder', 'rows', 'tabindex']
			placeholder: (->
					'Tell a story about ' + @get('controller.nickname') + ', describe a secret talent, whatever!'
				).property 'controller.nickname'
			rows: 3
			tabindex: 3
