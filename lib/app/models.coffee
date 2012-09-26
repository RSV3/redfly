module.exports = (DS, App) ->
	App.User = DS.Model.extend
		date: DS.attr 'date'
		email: DS.attr 'string'
		name: DS.attr 'string'
		classifyIndex: DS.attr 'number'
		classify: DS.hasMany 'App.Contact'

	App.Contact = DS.Model.extend
		date: DS.attr 'date'
		name: DS.attr 'string'
		email: DS.attr 'string'
		addedBy: DS.belongsTo 'App.User'
		dateAdded: DS.attr 'date'
		knows: DS.hasMany 'App.User'
		# TODO consider sideloading these?
		# tags: DS.hasMany 'App.Tag'
		# notes: DS.hasMany 'App.Note'
		nickname: (->
				util = require '../util'
				util.nickname @get('name')
			).property 'name'
		notes: (->
				mutable = []
				@get('_rawNotes').forEach (note) ->
					mutable.push note
				mutable
			).property '_rawNotes.@each', '_rawNotes.isLoaded'
		_rawNotes: (->
				App.Note.find
					conditions:
						contact: @get('id')
					options:
						sort: '-date'	# TODO why aren't these sorted appropriately. Sort param is being ignored entirely, comes back in natural order (which happens to be insertion order). Fix all other sorts too.
				# TODO
				# App.Note.find()
				# App.store.filter App.Note, (data) =>
				# 	data.contact is @get('id')
			).property()

	App.Tag = DS.Model.extend
		date: DS.attr 'date'
		creator: DS.belongsTo 'App.User'
		contact: DS.belongsTo 'App.Contact'
		category: DS.attr 'string'
		body: DS.attr 'string'

	App.Note = DS.Model.extend
		date: DS.attr 'date'
		author: DS.belongsTo 'App.User'
		contact: DS.belongsTo 'App.Contact'
		body: DS.attr 'string'
		preview: (->
				maxLength = 80
				preview = @get('body')[..maxLength]
				if preview.length is maxLength
					preview += '...'
				preview
			).property 'body'

	App.Mail = DS.Model.extend
		date: DS.attr 'date'
		sender: DS.belongsTo 'App.User'
		recipient: DS.belongsTo 'App.Contact'
		subject: DS.attr 'string'
		dateSent: DS.attr 'date'
