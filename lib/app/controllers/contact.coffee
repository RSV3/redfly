module.exports = (Ember, App, socket) ->
	util = require '../../util'


	App.ContactController = Ember.ObjectController.extend
		currentNote: null
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


	App.ContactView = Ember.View.extend
		template: require '../../../views/templates/contact'
		classNames: ['contact']
		newNoteView: Ember.TextArea.extend
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
