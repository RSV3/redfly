module.exports = (DS, App) ->
	tools = require '../util'


	App.adapter.registerTransform 'date',
		fromJSON: (value) ->
			new Date value
		toJSON: (value) ->
			value
			
	App.adapter.registerTransform 'array',
		fromJSON: (value) ->
			value
		toJSON: (value) ->
			value


	App.User = DS.Model.extend
		date: DS.attr 'date'
		email: DS.attr 'string'
		name: DS.attr 'string'
		queue: DS.hasMany 'App.Contact'
		excludes: DS.attr 'array'
		canonicalName: (->
				if this is App.user.get('content')
					return 'You'
				@get 'name'
			).property 'App.user.content', 'name'
		nickname: (->
				tools.nickname @get('name'), @get('email')
			).property 'name', 'email'

	App.Contact = DS.Model.extend
		date: DS.attr 'date'
		names: DS.attr 'array'
		emails: DS.attr 'array'
		knows: DS.hasMany 'App.User'
		added: DS.attr 'date'
		addedBy: DS.belongsTo 'App.User'
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
					data.get('contact.id') is @get('id')
			).property 'id'

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
				_s = require 'underscore.string'
				_s.prune @get('body'), 80
			).property 'body'

	App.Mail = DS.Model.extend
		date: DS.attr 'date'
		sender: DS.belongsTo 'App.User'
		recipient: DS.belongsTo 'App.Contact'
		subject: DS.attr 'string'
		sent: DS.attr 'date'
