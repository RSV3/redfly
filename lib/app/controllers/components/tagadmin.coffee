module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../../util.coffee'

	App.TagAdminView = Ember.View.extend
		template: require '../../../../templates/components/tagadmin.jade'
		classNames: ['tagadmin']
		catid: 'orgtagcat1'
		category: (->
			if (id = @get 'catid') is 'industry' then id
			else if (id = App.admin.get id) then id.toLowerCase()
			else 'organisation'
		).property 'catid', 'App.admin.orgtagcats'

		prioritytags: (->
			query = category: @get('category'), contact: null
			result = @get('parentView.controller').filter 'tag', query, (data) =>
				if (category = @get('category')) and (category isnt data.get('category'))
					return false
				not data.get('contact')
			options = sortProperties: ['date'], sortAscending: false, content: result, limit: 20
			Ember.ArrayProxy.createWithMixins Ember.SortableMixin, options
		).property 'category'

		saveAllTags: null
		saveTags: (->
			@set 'saveAllTags', null
			socket.emit 'tags.all', category: @get('category'), (allTags) =>
				result = Ember.ArrayController.create()
				result.pushObjects allTags.map (b)->b
				@set 'saveAllTags', result
		).observes 'category'
		didInsertElement: ->
			@saveTags()
		alltags: (->
			result = null
			if (allTags = @get 'saveAllTags.content')
				result = Ember.ArrayController.create()
				if allTags.length
					catid = @get 'catid'
					if p = @get('prioritytags').getEach 'body'
						allTags = _.difference allTags, p
					doLongList = (res, tags)->
						if not tags?.length then return
						res.pushObjects _.map tags[0..99], (b)=> {body:b, catid:catid}
						Ember.run.next this, ->
							doLongList res, tags[100..]
					if allTags.length then doLongList result, allTags
			result
		).property 'prioritytags.@each', 'saveAllTags.@each'

		hastags: (->
			(a = @get 'alltags') isnt null
		).property 'alltags'

		click: ->
			$(@get('newTagViewInstance.element')).focus()
		add: ->
			if tag = util.trim @get('currentTag')
				@_add tag
			@set 'currentTag', null
		_add: (tag) ->
			if not (existingTag = @get('prioritytags.content')?.find (candidate) -> tag is candidate.body)
				t = @get('controller').store.createRecord 'tag',
					date: new Date
					category: @get('category')
					body: tag
				t.save()
				@set 'animate', true
			else
				# TODO do this better    @get('childViews').objectAt(0).get('context')      existingTag/@$().addClass 'animated pulse'
				@$(".body:contains('#{tag}')").parent().addClass 'animated pulse'

		tagView: App.TagView.extend
			rename: ->
				((that)->
					$that = that.$().find('a.body')
					width = $that.width()+20
					oldtxt = $that.text()
					oldhtml = $that[0].outerHTML
					$('input').prop('disabled', true)
					$newone = $("<input class='tagedit' value='#{oldtxt}'/>")
					handleInput = ->
						newtxt = $(this).val()
						if not newtxt or not newtxt.length then newtxt = oldtxt
						else
							renameObj =
								category: that.get 'parentView.category'
								body: oldtxt
								new: newtxt
							socket.emit 'tags.rename', renameObj, () =>
								that.set('context.body', newtxt)
								@get('parentView.controller').store.filter('tag', (t)->
									t.get('category') is renameObj.category and t.get('body') is renameObj.body
								).forEach (t)->
									t.set 'body', newtxt
									#t.transitionTo 'loaded.updated'
									t.get('stateManager').send 'becameClean'
						$(this).replaceWith(oldhtml).find('a.body').text newtxt
						$('input').prop('disabled', false)
					$that.replaceWith $newone
					$newone.width(width).focus().blur(handleInput).change(handleInput)
				)(@)
			add: ->
				tag = @get 'context'
				@$().addClass 'animated rotateOutDownLeft'
				if tag.body
					newtag = @get('controller').store.createRecord 'tag',
						date: new Date
						category: @get 'parentView.category'
						body: tag.body
					newtag.save()
				@set 'parentView.animate', true
			delete: ->
				@$().addClass 'animated rotateOutDownLeft'
				if tag = @get 'context'
					b = tag.body
					c = @get('parentView.category')
					Ember.run.later this, ->
						if tag.deleteRecord 		# priority tags are real tags ..
							tag.deleteRecord()
							tag.save()
						else								# .. but the 'alltags' list are just {body:} objs.
							if b?.length and c?.length		# we need to tell the server to remove any tags with the same name
								socket.emit 'tags.remove', {category: c, body: b}, (removedTags) =>
									while removedTags.length
										id = removedTags.shift()
										@get('parentView.controller').store.filter('tag', (t)-> t.get('isLoaded') and id is t.get 'id').get('firstObject')?.get('stateManager').goToState('deleted.saved')
					, 2345
			didInsertElement: ->
				that = this.get 'parentView'
				@$().draggable(
					helper: -> "<span class='tag'><span>&nbsp;<i class='icon-tag'></i>&nbsp; #{$(this).text()}</span></span>"
					zIndex:99
					revert:'invalid'
					opacity:'0.7'
					containment:$('body')
				).droppable(
					drop: (e, ui)->
						renameObj = 
							category: that.get 'category'
							body: util.trim ui.draggable.text()
							new: util.trim $(this).text()
						socket.emit 'tags.rename', renameObj, () =>
							ui.draggable.remove()
							@get('parentView.controller').store.filter('tag', (t)->
								t.get('category') is renameObj.category and t.get('body') is renameObj.body
							).forEach (t)-> t.set 'body', renameObj.new
				).addClass(that.get 'catid').addClass(that.get 'category')
				$('ul.nav-tabs a').click (e)->
					e.preventDefault()
					that.set 'catid', $(this).attr 'href'
					$(this).tab 'show'
				$('ul.nav-tabs li').droppable({
					drop: (e, ui)->
						if not $(this).hasClass 'active'
							moveObj =
								category: that.get 'category'
								body: util.trim ui.draggable.text()
								newcat: util.trim $(this).find('a').attr 'href'
							socket.emit 'tags.move', moveObj, () =>
								ui.draggable.remove()
								that.set('context.category', moveObj.newcat)
								@get('parentView.controller').store.filter('tag', (t)->
									t.get('category') is moveObj.category and t.get('body') is moveObj.body
								).forEach (t)-> t.set 'category', moveObj.newcat
				})

				if @get 'parentView.animate'
					@set 'parentView.animate', false
					@$().addClass 'animated bounceIn'

		newTagView: App.NewTagView.extend()

