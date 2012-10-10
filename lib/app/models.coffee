module.exports = (DS, App) ->

	DS.attr.transforms.array =
		from: (serialized) ->
			Ember.ArrayProxy.create content: serialized
		to: (deserialized) ->
			throw new Error 'unimplemented'
			# deserialized.toArray() order is not guaranteed


	App.User = DS.Model.extend
		date: DS.attr('date', key: 'date')
		email: DS.attr('string', key: 'email')
		canonicalName: DS.attr('string', key: 'name')
		queue: DS.hasMany('App.Contact', key: 'queue')
		excludes: DS.attr('array', key: 'excludes')
		name: (->
				# TODO figure out a cleaner way to do entity equality
				if App.user.get('id') is @get('id')
					return 'You'
				@get 'canonicalName'
			).property 'canonicalName'

	App.Contact = DS.Model.extend
		date: DS.attr('date', key: 'date')
		names: DS.attr('array', key: 'names')
		emails: DS.attr('array', key: 'emails')
		knows: DS.hasMany('App.User', key: 'knows')
		added: DS.attr('date', key: 'added')
		addedBy: DS.belongsTo('App.User', key: 'addedBy')
		# TODO consider sideloading these?
		# tags: DS.hasMany 'App.Tag'
		# notes: DS.hasMany 'App.Note'
		name: (->
				if name = @get('primaryName')
					return name
				if email = @get('email')
					return email[...email.lastIndexOf('.')]
				null
			).property 'primaryName', 'email'
		nickname: (->
				tools = require '../util'
				tools.nickname @get('primaryName'), @get('email')
			).property 'primaryName', 'email'
		email: (->
				@get('emails.firstObject')
			).property 'emails.@each'
		primaryName: (->
				@get('names.firstObject')
			).property 'names.@each'
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
				_s = require 'underscore.string'
				_s.prune @get('body'), 80
			).property 'body'

	App.Mail = DS.Model.extend
		date: DS.attr('date', key: 'date')
		sender: DS.belongsTo('App.User', key: 'sender')
		recipient: DS.belongsTo('App.Contact', key: 'recipient')
		subject: DS.attr('string', key: 'subject')
		sent: DS.attr('date', key: 'sent')
