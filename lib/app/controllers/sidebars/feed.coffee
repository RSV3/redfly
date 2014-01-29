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

	App.JustuserView = App.HoveruserView.extend
		template: require '../../../templates/components/leaduser'

	App.FeedView = Ember.View.extend
		template: require '../../../../templates/sidebars/feed'
		userview: App.JustuserView.extend()
		didInsertElement: ->
			socket.on 'feed', (data) =>
				if not data?.id then return
				model = type = data.type
				if type is 'linkedin' then model = 'Contact'
				Ember.run.next this, ->
					if item = App[model].find data.id
						if item.get('isLoaded') and data.doc
							for own key,val of data.doc
								if _.isString(val) and not item.get(key)?.length
									item.set(key, val)
						item['type' + _s.capitalize(type)] = true
						if (id = data.updater or data.addedBy) then item.set 'updatedBy', App.User.find id
						if f = @get('controller.feed') then f.unshiftObject item

		feedItemView: Ember.View.extend
			classNames: ['feed-item']
			didInsertElement: ->
				@$().addClass 'animated flipInX'
				Ember.run.later this, ->
					@$().removeClass 'animated flipInX'
				, 1000

