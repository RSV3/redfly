module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../../util.coffee'

	App.TaggerView = Ember.View.extend
		template: require '../../../../templates/components/tagger.jade'
		classNames: ['tagger']
		category: (->
			switch (id = @get 'catid')
				when 'industry' then id
				when 'orgtagcat1' then App.admin.get('orgtagcat1').toLowerCase()
				when 'orgtagcat2' then App.admin.get('orgtagcat2').toLowerCase()
				when 'orgtagcat3' then App.admin.get('orgtagcat3').toLowerCase()
				else null
		).property 'catid'
		tags: (->
			#sort = field: 'date'
			query = contact: @get('contact.id')
			if category = @get('category') then query.category = category
			@get('controller').store.filter 'tag', query, (data) =>
				if category and (category isnt data.get('category'))
					return false
				data.get('contact.id') is @get('contact.id')
		).property 'contact.id', 'category'

		tagView: App.TagView.extend
			didInsertElement: ->
				cat = @get('parentView.category') or @get('context.category')
				@$().addClass cat
				for i in [1..3]
					id = "orgtagcat#{i}"
					if cat is App.admin.get(id).toLowerCase() then @$().addClass id

		newTagView: App.NewTagView.extend()

