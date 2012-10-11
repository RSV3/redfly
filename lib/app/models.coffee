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
		queue: (->
				if not @get '_queue.isLoaded'
					ids = []
					@get('_queue.content').forEach (clientId) ->
						ids.push App.store.clientIdToId[clientId]
					App.Contact.find _id: $in: ids
				@get '_queue'
			).property '_queue.@each', '_queue.isLoaded'
		_queue: DS.hasMany('App.Contact', key: 'queue')
		excludes: DS.attr('array', key: 'excludes')
		name: (->
				# TODO figure out a cleaner way to do entity equality
				if App.user.get('id') is @get('id')
					return 'You'
				@get 'canonicalName'
			).property 'id', 'App.user.id', 'canonicalName'

	App.Contact = DS.Model.extend
		date: DS.attr('date', key: 'date')
		names: DS.attr('array', key: 'names')
		emails: DS.attr('array', key: 'emails')
		knows: (->
				# if not @get '_knows.isLoaded'
				ids = []
				@get('_knows.content').forEach (clientId) ->
					ids.push App.store.clientIdToId[clientId]
				App.User.find _id: $in: ids
				@get '_knows'
			).property '_knows.@each', '_knows.isLoaded'
		_knows: DS.hasMany('App.User', key: 'knows')
		added: DS.attr('date', key: 'added')
		addedBy: DS.belongsTo('App.User', key: 'addedBy')
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
