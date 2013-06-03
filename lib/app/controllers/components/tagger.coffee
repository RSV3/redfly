module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../../util'

	App.TaggerView = Ember.View.extend
		template: require '../../../../templates/components/tagger'
		classNames: ['tagger']
		tags: (->
			sort = field: 'date'
			query = contact: @get('contact.id'), category: @get('category')
			App.filter App.Tag, sort, query, (data) =>
				if (category = @get('category')) and (category isnt data.get('category'))
					return false
				data.get('contact.id') is @get('contact.id')
		).property 'contact.id', 'category'

		tagView: App.TagView.extend
			didInsertElement: ->
				@$().addClass(@get('parentView.category') or @get('context.category'))

		newTagView: App.NewTagView.extend()

