module.exports = (DS, App) ->
	App.User = DS.Model.extend
		date: DS.attr('date', key: 'date')
		email: DS.attr('string', key: 'email')
		name: DS.attr('string', key: 'name')
		classifyQueue: DS.hasMany('App.Contact', key: 'classifyQueue')
		classifyIndex: DS.attr('number', key: 'classifyIndex')

	App.Contact = DS.Model.extend
		date: DS.attr('date', key: 'date')
		name: DS.attr('string', key: 'name')
		email: DS.attr('string', key: 'email')
		knows: DS.hasMany('App.User', key: 'knows')
		added: DS.attr('date', key: 'added')
		addedBy: DS.belongsTo('App.User', key: 'addedBy')
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
			).property '_rawNotes.@each'
		_rawNotes: (->
				# TODO have a check here to wait for isLoaded? See if this getting run before thid ID is there actually happens. This probably 
				# isn't likely.
				App.Note.find
					conditions:
						contact: @get('id')
					options:
						sort: date: -1
				# TODO
				# App.Note.find()
				# App.store.filter App.Note, (data) =>
				# 	data.contact is @get('id')
			).property()

	App.Tag = DS.Model.extend
		date: DS.attr('date', key: 'date')
		creator: DS.belongsTo('App.User', key: 'creator')
		contact: DS.belongsTo('App.Contact', key: 'contact')
		category: DS.attr('string', key: 'category')
		body: DS.attr('string', key: 'body')

	App.Note = DS.Model.extend
		date: DS.attr('date', key: 'date')
		author: DS.belongsTo('App.User', key: 'author')
		contact: DS.belongsTo('App.Contact', key: 'contact')
		body: DS.attr('string', key: 'body')
		preview: (->
				maxLength = 80
				preview = @get('body')[..maxLength]
				if preview.length is maxLength
					preview += '...'
				preview
			).property 'body'

	App.Mail = DS.Model.extend
		date: DS.attr('date', key: 'date')
		sender: DS.belongsTo('App.User', key: 'sender')
		recipient: DS.belongsTo('App.Contact', key: 'recipient')
		subject: DS.attr('string', key: 'subject')
		sent: DS.attr('date', key: 'sent')
