module.exports = (DS, App) ->
	tools = require '../util'


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
		nickname: (->
				tools.nickname @get('canonicalName'), @get('email')
			).property 'canonicalName', 'email'

	App.Contact = DS.Model.extend
		date: DS.attr 'date'
		names: DS.attr 'array'
		emails: DS.attr 'array'
		knows: DS.hasMany 'App.User'
		added: DS.attr 'date'
		addedBy: DS.belongsTo('App.User', key: 'addedBy')
		name: (->
				@get('names.firstObject')
			).property 'names.@each'
		email: (->
				@get('emails.firstObject')
			).property 'emails.@each'
		canonicalName: (->
				if name = @get('name')
					return name
				if email = @get('email')
					return email[...email.lastIndexOf('.')]
				null
			).property 'name', 'email'
		nickname: (->
				tools.nickname @get('name'), @get('email')
			).property 'name', 'email'
		notes: (->
				App.Note.find contact: @get('id')
					# conditions:
					# 	contact: @get('id')
					# options:
					# 	sort: date: 1
				App.Note.filter (data) =>
					data.get('contact') is @get('id')
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
