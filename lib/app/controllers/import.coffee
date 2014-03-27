module.exports = (Ember, App) ->
	_ = require 'underscore'
	_s = require 'underscore.string'

	util = require '../util.coffee'
	validation = require('../validation.coffee')()

	validate = validation.validate
	filter = validation.filter


	App.ImportController = Ember.Controller.extend
		currentState: null
		recCnt: 0

		# applies transformation to data rows (ie. not the first row)
		doTransformation: (transform, data)->
			result =
				notes: []
				status: {}
			transform result, data
			@set 'recCnt', 1 + @get 'recCnt'

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
				result.fields = []
				_.each @get('processed.fields'), (f)->
					result.fields.push result[f.toLowerCase()]
				@get('processed.results').pushObject result
				if @get('processed.results.length') is @get 'recCnt'
					@set 'currentState', 'parsed'

		# operates on header row that has field names
		setTransform: (data)->
			@set 'recCnt', 0
			fields = []
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
			@set 'processed.fields', _.sortBy _.uniq(fields), (field) ->
				['Emails', 'Names', 'Tags', 'Notes'].indexOf field
			return (result, raw) ->
				func result, raw for func in functions

		_process: ->
			# Buffer needs to be available globally to use the csv module as-written. Oh well.
			window.Buffer = require('buffer').Buffer

			reader = new FileReader
			reader.onload = (upload) =>
				transform = null
				require('csv')()
					.from.string(upload.target.result)
					.on 'record', (data) =>
						data = _.map data, (item) -> util.trim item
						if _.isEmpty _.compact data then return		# Ignore blank rows.
						if not transform then transform = @setTransform data	# first row field names
						else @doTransformation transform, data	# real data!
					.on 'end', (count)=>
						console.log 'csv loaded'
					.on 'error', (err)=>
						@set 'error', 'Something went wrong during parsing: ' + err.message
						console.dir err
						@set 'currentState', 'start'

			reader.readAsText @get('file')



	App.ImportView = Ember.View.extend
		template: require '../../../templates/import.jade'
		classNames: ['import']

		didInsertElement: ->
			@set 'controller.currentState', 'start'

		startView: Ember.View.extend
			isVisible: (->
				@get('controller.currentState') is 'start'
			).property 'controller.currentState'

			fileInputView: Ember.View.extend
				tagName: 'input'
				attributeBindings: ['type']
				type: 'file'
				change: (event) ->
					if file = _.first event.target.files
						if file.type isnt 'text/csv'
							return @set 'controller.error', 'This doesn\'t appear to be a csv file.'
						@set 'controller.file', file
						@set 'controller.error', null
						# Set initial state.
						@set 'controller.processed', {}
						@set 'controller.processed.results', []
						@get('controller')._process()
						@set 'controller.currentState', 'parsing'

		parsingView: Ember.View.extend
			isVisible: (->
				@get('controller.currentState') is 'parsing'
			).property 'controller.currentState'

		parsedView: Ember.View.extend
			isVisible: (->
				@get('controller.currentState') is 'parsed'
			).property 'controller.currentState'
			reset: ->
				@set 'controller.error', null
				@set 'controller.currentState', 'start'
			import: ->
				store = @get('parentView.controller').store
				@get('controller.processed.results').forEach (result) ->
					if not result.status.new then return
					contact = store.createRecord 'contact',
						emails: result.emails
						names: result.names
						knows: Ember.ArrayProxy.create {content: [App.user]}
						added: new Date
						addedBy: App.user
					contact.save().then ->
						result.tags.forEach (tag)->
							t = store.createRecord 'tag',
								creator: App.user
								contact: contact
								category: 'industry'
								body: tag
							t.save()
						result.notes.forEach (note)->
							n = store.createRecord 'note',
								author: App.user
								contact: contact
								body: note
							n.save()
				@set 'controller.currentState', 'start'
				console.log 'transitioned to start'
				# Move to the top of the page so the user sees the new contacts coming into the feed.
				$('html, body').animate {scrollTop: '0px'}, 300

			resultFieldView: Ember.View.extend
				tagName: 'td'
				resultBinding: 'parentView.content'
				didInsertElement: ->
					@set 'type' + _s.capitalize(@get('content')), true

