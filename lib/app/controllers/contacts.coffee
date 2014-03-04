module.exports = (Ember, App) ->

	_ = require 'underscore'
	socketemit = require '../socketemit.coffee'

	batchFindQuery = (type, query) ->
		store = App.store
		adapter = store.adapter
		typeName = _.last type.toString().split('.')
		recordArray = DS.AdapterPopulatedRecordArray.create {type:type, query:query, content:Ember.A([]), store:store}
		socketemit.get 'db', {op: 'find', type: typeName, query: query}, (json)->
			Ember.run adapter, ->
				batchSize = 50
				item = _.first _.keys json
				items = json[item]
				f = (counter=0) =>
					Ember.run.later this, ->	# small delay gives better UX than next ...
						json[item] = items.slice counter*batchSize, (counter+1)*batchSize
						thisArray = DS.AdapterPopulatedRecordArray.create {type:type, query:query, content:Ember.A([]), store:App.store}
						adapter.didFindQuery store, type, json, thisArray
						recordArray.set 'content', recordArray.get('content').concat thisArray.get('content')
						counter++
						if counter*batchSize < items.length then f counter
					, 23
				f()
		return recordArray

	App.ContactsController = Ember.ObjectController.extend
		page1Contacts: []
		addedContacts: null
		addContacts: (->
			oneC = @get 'page1Contacts'
			if oneC and oneC.get 'length'
				@set 'addedContacts', batchFindQuery App.Contact, {
					conditions: added: $exists: true
					options: sort: added: -1
				}
		).observes 'page1Contacts.@each'

		contacts: (->
			allC = @get 'addedContacts'
			if allC?.get 'content.length'
				Ember.ArrayProxy.createWithMixins App.Pagination, content: allC
			else
				Ember.ArrayProxy.create content: @get 'page1Contacts'
		).property 'addedContacts.@each', 'page1Contacts'



	App.ContactsView = Ember.View.extend
		template: require '../../../templates/contacts.jade'
		classNames: ['contacts']
