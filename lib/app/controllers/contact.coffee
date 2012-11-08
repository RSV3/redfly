module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../../util'


	App.ContactController = Ember.ObjectController.extend
		histories: (->
				# TODO Hack. If clause only here to make sure that all the mails don't get pulled down on "all done" classify page where the
				# fake contact is below the page break and has no ID set
				if not @get('id')
					return []
				App.Mail.find
					conditions:
						sender: App.user.get('id')
						recipient: @get('id')
					options:
						sort: date: 1
			).property 'id'
		firstHistory: (->
				@get 'histories.firstObject'
			).property 'histories.firstObject'
		isKnown: (->
				@get('knows')?.find (user) ->
					user.get('id') is App.user.get('id')
			).property 'knows.@each.id'
		disableAdd: (->
				not util.trim @get('currentNote')
			).property 'currentNote'
		# emptyNotesText: (->
		# 		if Math.random() < 0.9
		# 			# return 'No notes about ' + @get('nickname') + ' yet.'	# TO-DO doesn't work?
		# 			return 'No notes about this contact yet.'
		# 		('...and that\'s why you ' +
		# 			' <a href="http://www.dailymotion.com/video/xrjyfz_that-s-why-you-always-leave-a-note_shortfilms" target="_blank">' +
		# 			 'always leave a note!</a>'
		# 		).htmlSafe()
		# 	).property().volatile()
		add: ->
			if note = util.trim @get('currentNote')
				App.Note.createRecord
					author: App.user
					contact: @get 'content'
					body: note
				App.store.commit()
				@set 'animate', true
				@set 'currentNote', null
		directMailto: (->
				'mailto:'+ @get('canonicalName') + ' <' + @get('email') + '>' + '?subject=What are the haps my friend!'
			).property 'canonicalName', 'email'
		introMailto: (->
				carriage = '%0D%0A'
				'mailto:' + @get('addedBy.canonicalName') + ' <' + @get('addedBy.email') + '>' +
					'?subject=You know ' + @get('canonicalName') + ', right?' +
					'&body=Hey ' + @get('addedBy.nickname') + ', would you kindly give me an intro to ' + @get('email') + '? Thanks!' +
					carriage + carriage + 'Your servant,' + carriage + App.user.get('nickname')
			).property 'canonicalName', 'email', 'addedBy.canonicalName', 'addedBy.email', 'addedBy.nickname', 'App.user.nickname'


	App.ContactView = Ember.View.extend
		template: require '../../../views/templates/contact'
		classNames: ['contact']

		editView: Ember.View.extend
			tagName: 'span'
			classNames: ['editor']
			primary: ((key, value) ->
					if arguments.length is 1
						return @get('controller.name')
					value
				).property 'controller.name'
			others: (->
					Ember.ArrayProxy.create content: @_makeProxyArray @get('controller.aliases')
				).property 'controller.aliases'
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
			done: ->
				@set 'working', true

				all = @get('others').getEach 'content'
				all.unshift @get('primary')
				all = _.chain(all)
					.map (item) ->
						util.trim item
					.compact()
					.value()
				# Set primary and others to the new values so the user can see any modifications to the input while stuff saves.
				@set 'primary', _.first all
				@set 'others.content', @_makeProxyArray _.rest all
				socket.emit 'verifyUniqueness', @get('controller.id'), 'name', all, (duplicate) =>
					@set 'duplicate', duplicate
					if not duplicate
						@set 'controller.names', all
						App.store.commit()
						@toggle()

					@set 'working', false

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

		introView: Ember.View.extend
			tagName: 'i'
			didInsertElement: ->
				$(@$()).tooltip()
			attributeBindings: ['rel', 'dataTitle:data-title', 'dataPlacement:data-placement']
			rel: 'tooltip'
			dataTitle: (->
					'Ask ' + @get('controller.addedBy.nickname') + ' for an intro!'
				).property 'controller.addedBy.nickname'
			dataPlacement: 'right'

		newNoteView: Ember.TextArea.extend
			classNames: ['span12']
			attributeBindings: ['placeholder', 'rows', 'tabindex']
			placeholder: (->
					'Tell a story about ' + @get('controller.nickname') + ', describe a secret talent, whatever!'
				).property 'controller.nickname'
			rows: 3
			tabindex: 3

		noteView: Ember.View.extend
			tagName: 'blockquote'
			didInsertElement: ->
				if @get 'controller.animate'
					@set 'controller.animate', false
					@$().addClass 'animated flipInX'
