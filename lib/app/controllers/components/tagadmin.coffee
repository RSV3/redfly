module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../../util'

	App.TagAdminView = Ember.View.extend
		template: require '../../../../templates/components/tagadmin'
		classNames: ['tagadmin']
		category: 'industry'
		prioritytags: (->
			query = category: @get('category'), contact: $exists: false
			result = App.Tag.filter query, (data) =>
				if (category = @get('category')) and (category isnt data.get('category'))
					return false
				not data.get('contact')
			options = sortProperties: ['date'], sortAscending: false, content: result, limit: 20
			Ember.ArrayProxy.createWithMixins Ember.SortableMixin, options
		).property 'category'
		alltags: (->
			result = Ember.ArrayController.create()
			if c = @get('category')
				socket.emit 'tags.all', category: c, (allTags) =>
					allTags = _.difference allTags, @get('prioritytags').getEach 'body'
					result.set 'content', _.map allTags, (t)->{body:t}
			result
		).property 'prioritytags.@each'
		hastags: (->
			@get('alltags')?.get('length')
		).property 'alltags.@each'

		click: ->
			$(@get('newTagViewInstance.element')).focus()
		add: ->
			if tag = util.trim @get('currentTag')
				@_add tag
			@set 'currentTag', null
		_add: (tag) ->
			existingTag = @get('prioritytags.content').find (candidate) ->
				tag is candidate.body
			if not existingTag
				t = App.Tag.createRecord
					date: new Date
					category: @get('category')
					body: tag
				App.store.commit()
				@set 'animate', true
			else
				# TODO do this better    @get('childViews').objectAt(0).get('context')      existingTag/@$().addClass 'animated pulse'
				@$(".body:contains('#{tag}')").parent().addClass 'animated pulse'

		tagView: App.TagView.extend
			add: ->
				tag = @get 'context'
				@$().addClass 'animated rotateOutDownLeft'
				newtag = App.Tag.createRecord
					date: new Date
					category: @get 'parentView.category'
					body: tag.body
				App.store.commit()
				@set 'parentView.animate', true
			delete: ->
				tag = @get 'context'
				@$().addClass 'animated rotateOutDownLeft'
				setTimeout =>
					if tag.deleteRecord 		# priority tags are real tags
						tag.deleteRecord()
						App.store.commit()
					else						# the 'alltags' list are just {body:} objs.
												# we need to tell the server to remove any tags with the same name
						if c = @get('parentView.controller.category')
							socket.emit 'tags.remove', {category: c, body: tag.body}, (removedTags) =>
								while removedTags.length
									id = removedTags.shift()
									App.store.filter(App.Tag, (t)-> t.get('isLoaded') and id is t.get 'id').get('firstObject')?.get('stateManager').goToState('deleted.saved')
				, 1000
			didInsertElement: ->
				that = this.get 'parentView'
				$('ul.nav-tabs a').click (e)->
					e.preventDefault()
					that.set 'category', $(this).attr 'href'
					$(this).tab 'show'

				if @get 'parentView.animate'
					@set 'parentView.animate', false
					@$().addClass 'animated bounceIn'

		newTagView: App.NewTagView.extend()

		# TODO:
		# the stuff above is quite different from the contact page cloud tag stuff,
		# but this here below has been cutnpaste verbatim from tagger:
		# it really should be its own component.


