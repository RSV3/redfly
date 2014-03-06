module.exports = (Ember, App) ->
	_ = require 'underscore'
	_s = require 'underscore.string'

	App.FeedController = Ember.Controller.extend
		feed: (->
			mutable = []
			if contacts = @get '_initialContacts'
				contacts.forEach (contact) ->
					item = Ember.ObjectProxy.create content:contact
					item.typeInitialContact = true
					item.when = require('moment')(contact.get "added").fromNow()
					mutable.push item
			mutable
		).property '_initialContacts.@each'
		_initialContacts: (->
			this.store.find 'contact',
				conditions:
					added: $exists: true
				options:
					sort: added: -1
					limit: 5
			).property()

	App.JustuserView = App.HoveruserView.extend
		template: require '../../../../templates/components/leaduser.jade'

	App.FeedView = Ember.View.extend
		template: require '../../../../templates/sidebars/feed.jade'
		userview: App.JustuserView.extend()
		didInsertElement: ->
			###
			#socket.on 'feed', (data) =>
				if not data?.id then return
				model = type = data.type?.toLowerCase()
				if type is 'linkedin' then model = 'contact'
				Ember.run.next this, ->
					if item = this.store.find model, data.id
						if item.get('isLoaded') and data.doc
							for own key,val of data.doc
								if _.isString(val) and not item.get(key)?.length
									item.set(key, val)
						item['type' + _s.capitalize(type)] = true
						if (id = data.updater or data.addedBy) then item.set 'updatedBy', this.store.find 'user', id
						if f = @get('controller.feed') then f.unshiftObject item
			###

		feedItemView: Ember.View.extend
			classNames: ['feed-item']
			didInsertElement: ->
				@$().addClass 'animated flipInX'
				Ember.run.later this, ->
					@$().removeClass 'animated flipInX'
				, 1000

