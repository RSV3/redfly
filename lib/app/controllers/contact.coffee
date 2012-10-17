module.exports = (Ember, App, socket) ->
	util = require '../../util'


	App.ContactController = Ember.ObjectController.extend
		histories: (->
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
				# TO-DO there has to be better way to do 'contains'. Preserve the testing for nonexistence of get(knows)
				has = false
				if knowsed = @get('knows')
					knowsed.forEach (user) ->
						if user.get('id') is App.user.get('id')
							has = true
				has
			).property 'knows.@each.id'
		disableAdd: (->
				if util.trim @get('currentNote')
					return false
				return true
			).property 'currentNote'
		emptyNotesText: (->
				if Math.random() < 0.9
					# return 'No notes about ' + @get('nickname') + ' yet.'	# TO-DO doesn't work?
					return 'No notes about this contact yet.'
				('...and that\'s why you ' +
					' <a href="http://www.dailymotion.com/video/xrjyfz_that-s-why-you-always-leave-a-note_shortfilms" target="_blank">' +
					 'always leave a note!</a>'
				).htmlSafe()
			).property().volatile()
		add: ->
			if note = util.trim @get('currentNote')
				newNote = App.store.createRecord App.Note,	# TODO will this work as App.Note.createRecord? Change here and elsewhere.
					author: App.user
					contact: @get 'content'
					body: note
				App.store.commit()
				@set 'animate', true
				@get('notes').unshiftObject newNote
				@set 'currentNote', null
		directMailto: (->
				'mailto:'+ @get('name') + ' <' + @get('email') + '>' + '?subject=What are the haps my friend!'
			).property 'name', 'email'
		introMailto: (->
				carriage = '%0D%0A'
				'mailto:' + @get('addedBy.canonicalName') + ' <' + @get('addedBy.email') + '>' +
					'?subject=You know ' + @get('name') + ', right?' +
					'&body=Hey ' + @get('addedBy.nickname') + ', would you kindly give me an intro to ' + @get('email') + '? Thanks!' +
					carriage + carriage + 'Your servant,' + carriage + App.user.get('nickname')
			).property 'name', 'email', 'addedBy.canonicalName', 'addedBy.email', 'addedBy.nickname', 'App.user.nickname'


	App.ContactView = Ember.View.extend
		template: require '../../../views/templates/contact'
		classNames: ['contact']

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
			attributeBindings: ['placeholder', 'rows']
			placeholder: (->
					'Tell a story about ' + @get('controller.nickname') + ', describe a secret talent, whatever!'
				).property 'controller.nickname'
			rows: 3

		noteView: Ember.View.extend
			tagName: 'blockquote'
			didInsertElement: ->
				if @get 'controller.animate'
					@set 'controller.animate', false
					@$().addClass 'animated flipInX'
