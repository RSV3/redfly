module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'

	App.FeedController = Ember.Controller.extend
		feed: (->
				mutable = []
				@get('_initialContacts').forEach (contact) ->
					item = Ember.ObjectProxy.create content:contact
					item.typeInitialContact = true
					item.when = require('moment')(contact.get "added").fromNow()
					mutable.push item
				mutable
			).property '_initialContacts.@each'
		_initialContacts: (->
				App.Contact.find
					conditions:
						added: $exists: true
					options:
						sort: added: -1
						limit: 5
			).property()

	App.FeedView = Ember.View.extend
		template: require '../../../../templates/sidebars/feed'
		didInsertElement: ->
			socket.on 'feed', (data) =>
				if not data?.id then return
				model = type = data.type
				if type is 'linkedin' then model = 'Contact'
				Ember.run.next this, ->
					if item = App[model].find data.id
						item['type' + _s.capitalize(type)] = true
						item.set 'updatedBy', App.User.find data.updater
						if f = @get('controller.feed') then f.unshiftObject item

		feedItemView: Ember.View.extend
			classNames: ['feed-item']
			didInsertElement: ->
				@$().addClass 'animated flipInX'

