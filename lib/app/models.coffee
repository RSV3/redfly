module.exports = (DS, App) ->
	App.User = DS.Model.extend
		primaryKey: '_id'
		date: DS.attr 'date'
		email: DS.attr 'string'
		name: DS.attr 'string'
		classifyIndex: DS.attr 'number'
		classify: DS.hasMany 'App.Contact'

	App.Contact = DS.Model.extend
		primaryKey: '_id'
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
		tags: (->
				mutable = []
				@get('rawTags').forEach (tag) ->
					mutable.push tag
				mutable
			).property 'rawTags.@each', 'rawTags.isLoaded'
		rawTags: (->
				if @get '_id'
					App.Tag.find contact: @get('_id')
				else
					[]
			).property('isLoaded')
		notes: (->
				mutable = []
				@get('rawNotes').forEach (note) ->
					mutable.push note
				mutable
			).property 'rawNotes.@each', 'rawNotes.isLoaded'
		rawNotes: (->
				if @get '_id'
					App.Note.find
						conditions:
							contact: @get('_id')
						options:
							sort: '-date'	# TODO XXX why aren't these sorted appropriately
				else
					[]
				# TODO XXX
				# App.Note.find()
				# App.store.filter App.Note, (data) =>
				# 	data.contact is @get('_id')
			).property('isLoaded')

	# DS.attr.transforms.tags = 
	# 	to: ->

	App.Tag = DS.Model.extend
		primaryKey: '_id'
		date: DS.attr 'date'
		creator: DS.belongsTo 'App.User'
		contact: DS.belongsTo 'App.Contact'
		body: DS.attr 'string'

	App.Note = DS.Model.extend
		primaryKey: '_id'
		date: DS.attr 'date'
		author: DS.belongsTo 'App.User'
		contact: DS.belongsTo 'App.Contact'
		body: DS.attr 'string'

	App.Mail = DS.Model.extend
		primaryKey: '_id'
		date: DS.attr 'date'
		sender: DS.belongsTo 'App.User'
		recipient: DS.belongsTo 'App.Contact'
		subject: DS.attr 'string'
		dateSent: DS.attr 'date'
