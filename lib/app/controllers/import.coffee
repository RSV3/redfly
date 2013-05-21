module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'

	util = require '../util'
	validation = require('../validation') socket

	validate = validation.validate
	filter = validation.filter


	App.ImportController = Ember.Controller.extend
		stateMachine: (->
				Ember.StateManager.create
					start: Ember.State.create()
					parsing: Ember.State.create
						enter: => # Bind 'this' to the controller.
							@set 'error', null
							# Set initial state.
							@set 'processed', {}
							@set 'processed.results', []
							@_process()
					parsed: Ember.State.create()
			).property()

		_process: ->
			# Buffer needs to be available globally to use the csv module as-written. Oh well.
			window.Buffer = require('buffer').Buffer

			reader = new FileReader
			reader.onload = (upload) =>
				fields = []
				transform = null
				require('csv')()
					.from.string(upload.target.result)
					.on 'record', (data) =>
						data = _.map data, (item) ->
							util.trim item
						# Ignore blank rows.
						if _.isEmpty _.compact data
							return

						if not transform
							functions = []
							arrayify = (string) ->
								_.map string.split(','), (item) ->
									util.trim item
							normalizedData = _.map data, (cell) ->
								cell.toLowerCase()
							data.forEach (entry, index) ->
								if not entry
									return
								normalizedEntry = entry.toLowerCase()
								if normalizedEntry in ['email', 'tag', 'note']	# 'name' is handled specially.
									normalizedEntry += 's'
								if _s.contains normalizedEntry, 'name'
									if _s.contains normalizedEntry, 'first'
										lastNameEntry = _.find normalizedData, (candidate) ->
											_s.contains(candidate, 'name') and _s.contains(candidate, 'last')
										lastNameIndex = normalizedData.indexOf lastNameEntry
										functions.push do (index, lastNameIndex) ->
											(result, raw) ->
												if raw[index] and raw[lastNameIndex]
													result.names = [raw[index] + ' ' + raw[lastNameIndex]]
												else if raw[index]
													result.names = [raw[index]]
									else if 'Names' not in fields	# Ensure name transform isn't done already.
										functions.push do (index) ->
											(result, raw) ->
												if raw[index]
													result.names = arrayify raw[index]
									fields.push 'Names'
								else if normalizedEntry in ['emails', 'tags']
									functions.push do (index) ->
										(result, raw) ->
											if raw[index]
												result[normalizedEntry] = arrayify raw[index]
									fields.push _s.capitalize(normalizedEntry)
								else if normalizedEntry is 'notes'
									functions.push do (index) ->
										(result, raw) ->
											if raw[index]
												result.notes.unshift raw[index]	# Put "proper" notes at the beginning.
									fields.push _s.capitalize(normalizedEntry)
								else
									functions.push do (index) ->
										(result, raw) ->
											if raw[index]
												result.notes.push entry + ': ' + raw[index]
									fields.push 'Notes'
							transform = (result, raw) ->
								func result, raw for func in functions
							fields = _.sortBy _.uniq(fields), (field) ->
								['Emails', 'Names', 'Tags', 'Notes'].indexOf field
							@set 'processed.fields', fields
						else
							result =
								notes: []
								status: {}
							transform result, data

							result.names = filter.contact.names result.names
							result.emails = filter.contact.emails result.emails
							result.tags = _.chain(result.tags)
								.map (item) ->
									item.toLowerCase()
								.compact()
								.uniq()
								.value()
							require('async').forEach ['emails', 'names'], (field, cb) ->
								validate.contact[field] result[field], cb
							, (message) =>
								if message is "blacklisted" # hacky
									result.status.blacklisted = true
								else if message
									result.status.error = message
								else
									result.status.new = true
								@get('processed.results').pushObject result
					.on 'end', (count) =>
						@get('stateMachine').transitionToRoute 'parsed'
					.on 'error', (err) =>
						@set 'error', 'Something went wrong during parsing: ' + err.message
						@get('stateMachine').transitionToRoute 'start'

			reader.readAsText @get('file')



	App.ImportView = Ember.View.extend
		template: require '../../../templates/import'
		classNames: ['import']

		startView: Ember.View.extend
			isVisible: (->
					@get('controller.stateMachine.currentState.name') is 'start'
				).property 'controller.stateMachine.currentState.name'

			fileInputView: Ember.View.extend
				tagName: 'input'
				attributeBindings: ['type']
				type: 'file'
				change: (event) ->
					if file = _.first event.target.files
						if file.type isnt 'text/csv'
							return @set 'controller.error', 'This doesn\'t appear to be a csv file.'
						@set 'controller.file', file
						@get('controller.stateMachine').transitionToRoute 'parsing'

		parsingView: Ember.View.extend
			isVisible: (->
					@get('controller.stateMachine.currentState.name') is 'parsing'
				).property 'controller.stateMachine.currentState.name'

		parsedView: Ember.View.extend
			isVisible: (->
					@get('controller.stateMachine.currentState.name') is 'parsed'
				).property 'controller.stateMachine.currentState.name'
			reset: ->
				@set 'controller.error', null
				@get('controller.stateMachine').transitionToRoute 'start'
			import: ->
				@get('controller.processed.results').forEach (result) ->
					if not result.status.new
						return
					contact = App.Contact.createRecord
						emails: result.emails
						names: result.names
						knows: Ember.ArrayProxy.create {content: [App.user.get('content')]}
						added: new Date
						addedBy: App.user
					App.store.commit()
					# UPDATE: new version ember-data might let you batch commits with inter-foreign-key depenencies, making waiting for the
					# contact to get created unncessary
					contact.addObserver 'id', =>
					# TO-DO bring this back when ember-data is fixed
					# contact.one 'didCreate', =>
						result.tags.forEach (tag) ->
							App.Tag.createRecord
								creator: App.user
								contact: contact
								category: 'industry'
								body: tag
						result.notes.forEach (note) ->
							App.Note.createRecord
								author: App.user
								contact: contact
								body: note
						App.store.commit()
				@get('controller.stateMachine').transitionToRoute 'start'
				# Move to the top of the page so the user sees the new contacts coming into the feed.
				$('html, body').animate {scrollTop: '0px'}, 300

			resultFieldView: Ember.View.extend
				tagName: 'td'
				resultBinding: 'parentView.context'
				didInsertElement: ->
					@set 'type' + _s.capitalize(@get('content')), true

					# type = @get 'content'
					# if type in ['emails', 'names', 'notes']
					# 	type = 'default'
					# @set 'type' + _s.capitalize(type), true
