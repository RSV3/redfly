module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	_s = require 'underscore.string'

	App.FeedController = Ember.Controller.extend
		feed: (->
				mutable = []
				@get('_initialContacts').forEach (contact) ->
					item = Ember.ObjectProxy.create content:contact
					item.typeInitialContact = true
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
				if not data or not data.id then return
				type = data.type
				model = type
				if type is 'linkedin' then model = 'Contact'
				item = Ember.ObjectProxy.create
					content: App[model].find data.id
				item['type' + _s.capitalize(type)] = true
				if type is 'linkedin'
					item['updater'] = App.User.find data.updater
				else if data.addedBy
					item['addedBy'] =  App.User.find data.addedBy
				f = @get('controller.feed')
				if f then f.unshiftObject item

		feedItemView: Ember.View.extend
			classNames: ['feed-item']
			didInsertElement: ->
				@$().addClass 'animated flipInX'

