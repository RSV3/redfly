module.exports = (Ember, App, socket) ->

	App.PastreqsController = Ember.Controller.extend
		showthisreq:null

		my_reqs:null
		my_pageSize:0
		my_hasPrev: false
		my_hasNext: false
		my_rangeStart: 0
		my_hasPrev: (->
			@get('my_rangeStart')
		).property 'my_rangeStart'
		my_prevPage: (->
			socket.emit 'requests', {old:true, me:true, skip:@get('my_rangeStart')-@get('my_pageSize')}, (reqs, theresmore)=>
				if reqs
					@set 'my_reqs', App.store.findMany(App.Request, reqs)
					@set 'my_hasNext', true
					@set 'my_rangeStart', @get('my_rangeStart') - @get('my_pageSize')
		)
		my_nextPage: (->
			socket.emit 'requests', {old:true, me:true, skip:@get('my_rangeStart')+@get('my_pageSize')}, (reqs, theresmore)=>
				if reqs
					@set 'my_reqs', App.store.findMany(App.Request, reqs)
					@set 'my_hasNext', theresmore
					@set 'my_rangeStart', @get('my_rangeStart') + @get('my_pageSize')
		)

		other_reqs:null
		other_pageSize:0
		other_hasPrev: false
		other_hasNext: false
		other_rangeStart: 0
		other_hasPrev: (->
			@get('other_rangeStart')
		).property 'other_rangeStart'
		other_prevPage: (->
			socket.emit 'requests', {old:true, skip:@get('other_rangeStart')-@get('other_pageSize')}, (reqs, theresmore)=>
				if reqs
					@set 'other_reqs', App.store.findMany(App.Request, reqs)
					@set 'other_hasNext', true
					@set 'other_rangeStart', @get('other_rangeStart') - @get('other_pageSize')
		)
		other_nextPage: (->
			socket.emit 'requests', {old:true, skip:@get('other_rangeStart')+@get('other_pageSize')}, (reqs, theresmore)=>
				if reqs
					@set 'other_reqs', App.store.findMany(App.Request, reqs)
					@set 'other_hasNext', theresmore
					@set 'other_rangeStart', @get('other_rangeStart') + @get('other_pageSize')
		)

	App.PastreqsView = Ember.View.extend
		template: require '../../../../templates/sidebars/pastreqs'
		classNames: ['pastreqs']
		selectTab: (ev)->
			@$().find(".nav-tabs .active").removeClass 'active'
			@$().find(".nav-tabs .#{ev}").addClass 'active'
			@$().find(".tab-content .tab-pane.active").removeClass 'active'
			@$().find(".tab-content .tab-pane.#{ev}").addClass 'active'
		closeModal: (->
			@set 'controller.showthisreq', null
		)
		didInsertElement: ->
			socket.emit 'requests', {old:true}, (reqs, theresmore) =>
				if @get 'controller'	# in case we already switched out
					@set 'controller.other_hasNext', theresmore
					if theresmore then @set 'controller.other_pageSize', reqs.length
					if reqs then reqs = App.store.findMany App.Request, reqs
					@set 'controller.other_reqs', reqs
					socket.emit 'requests', {old:true, me:true}, (reqs, theresmore) =>
						if @get 'controller'	# in case we already switched out
							@set 'controller.my_hasNext', theresmore
							if theresmore then @set 'controller.my_pageSize', reqs.length
							if reqs then reqs = App.store.findMany App.Request, reqs
							@set 'controller.my_reqs', reqs
