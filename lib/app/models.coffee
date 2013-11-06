module.exports = (DS, App) ->
	_ = require 'underscore'
	util = require '../util'
	require('phrenetic/lib/app/models') DS, App, require '../schemas'

	App.Results = Em.Object.extend
		text: ''

	App.Admin.reopen
		contextio: DS.attr 'boolean'
		googleauth: DS.attr 'boolean'

	App.User.reopen
		canonicalName: (->
				if this is App.user then return 'You'
				@get 'name'
			).property 'App.user.content', 'name'
		nickname: (->
				util.nickname @get('name'), @get('email')
			).property 'name', 'email'
		canonicalPicture: (->
				@get('picture') or 'http://i.imgur.com/t1Svb.jpg'
			).property 'picture'
		classifyCount: DS.attr 'number'		# these are calculated on the server, transmitted on session user
		requestCount: DS.attr 'number'		# and then, just to make it interesting, stored on App.admin
											# (because session user data may get batch loaded)

	App.Contact.reopen
		name: (->
				@get 'names.firstObject'
			).property 'names.firstObject'
		aliases: (->
				_.rest @get('names')
			).property 'names.@each'
		email: (->
				@get 'emails.firstObject'
			).property 'emails.firstObject'
		otherEmails: (->
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


	App.Note.reopen
		preview: (->
				_s = require 'underscore.string'
				_s.prune _s.stripTags(@get 'body'), 80
			).property 'body'
