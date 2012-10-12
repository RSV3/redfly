module.exports = (DS, App) ->

	DS.attr.transforms.array =
		from: (serialized) ->
			Ember.ArrayProxy.create content: serialized
		to: (deserialized) ->
			throw new Error 'unimplemented'
			# deserialized.toArray() order is not guaranteed


	App.User = DS.Model.extend
		date: DS.attr 'date'
		email: DS.attr 'string'
		canonicalName: DS.attr('string', key: 'name')
		queue: DS.hasMany 'App.Contact'
		excludes: DS.attr 'array'
		name: (->
				# TODO figure out a cleaner way to do entity equality
				if App.user.get('id') is @get('id')
					return 'You'
				@get 'canonicalName'
			).property 'id', 'App.user.id', 'canonicalName'

	App.Contact = DS.Model.extend
		date: DS.attr 'date'
		names: DS.attr 'array'
		emails: DS.attr 'array'
		knows: DS.hasMany 'App.User'
		added: DS.attr 'date'
		addedBy:(DS.belongsTo 'App.User', key: 'addedBy')
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
				App.Note.find
					conditions:
						contact: @get('id')
					options:
						sort: date: -1
			).property 'id'

	App.Tag = DS.Model.extend
		date: DS.attr 'date'
		creator: DS.belongsTo('App.User', key: 'creator')
		contact: DS.belongsTo('App.Contact', key: 'contact')
		category: DS.attr 'string'
		body: DS.attr 'string'

	App.Note = DS.Model.extend
		date: DS.attr 'date'
		author: DS.belongsTo('App.User', key: 'author')
		contact: DS.belongsTo('App.Contact', key: 'contact')
		body: DS.attr 'string'
		preview: (->
				_s = require 'underscore.string'
				_s.prune @get('body'), 80
			).property 'body'

	App.Mail = DS.Model.extend
		date: DS.attr 'date'
		sender: DS.belongsTo('App.User', key: 'sender')
		recipient: DS.belongsTo('App.Contact', key: 'recipient')
		subject: DS.attr 'string'
		sent: DS.attr 'date'
