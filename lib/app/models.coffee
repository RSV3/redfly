module.exports = (DS, App) ->
	_ = require 'underscore'
	util = require '../util'


	App.adapter.registerTransform 'date',
		fromJSON: (value) ->
			if value
				date = new Date value
				throw new Error 'Invalid date.' if isNaN date
				return date
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
		picture: DS.attr 'string'
		queue: DS.hasMany 'App.Contact'
		excludes: DS.attr 'array'
		canonicalName: (->
				if this is App.user.get('content')
					return 'You'
				@get 'name'
			).property 'App.user.content', 'name'
		nickname: (->
				util.nickname @get('name'), @get('email')
			).property 'name', 'email'
		canonicalPicture: (->
				@get('picture') or 'http://i.imgur.com/t1Svb.jpg'
			).property 'picture'

	App.Contact = DS.Model.extend
		date: DS.attr 'date'
		names: DS.attr 'array'
		emails: DS.attr 'array'
		picture: DS.attr 'string'
		company: DS.attr 'string'
		position: DS.attr 'string'
		linkedin: DS.attr 'string'
		facebook: DS.attr 'string'
		twitter: DS.attr 'string'
		knows: DS.hasMany 'App.User'
		added: DS.attr 'date'
		addedBy: DS.belongsTo 'App.User'
		name: (->
				@get 'names.firstObject'
			).property 'names.firstObject'
		aliases: (->
				_.rest @get('names')
			).property 'names.@each'
		email: (->
				@get 'emails.firstObject'
			).property 'emails.firstObject'
		otherEmails: ( ->
				_.rest @get('emails')
			).property 'emails.@each'
		canonicalName: (->
				if name = @get('name')
					return name
				if email = @get('email')
					splitted = email.split '@'
					domain = _.first _.last(splitted).split('.')
					return _.first(splitted) + ' [' + domain + ']'
				null
			).property 'name', 'email'
		nickname: (->
				util.nickname @get('name'), @get('email')
			).property 'name', 'email'
		canonicalPicture: (->
				# https://lh4.googleusercontent.com/-CG7j6tomnZg/AAAAAAAAAAI/AAAAAAAAHAk/kDhN-Z5gNJc/s250-c-k/photo.jpg
				@get('picture') or 'http://media.zenfs.com/289/2011/07/30/movies-person-placeholder-310x310_160642.png'
			).property 'picture'
		notes: (->
				App.filter App.Note, {field: 'date'}, {contact: @get('id')}, (data) =>
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
