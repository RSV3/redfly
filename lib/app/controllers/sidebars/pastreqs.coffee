module.exports = (Ember, App, socket) ->

	App.PastreqsController = Ember.Controller.extend
		showthisreq:null
		my_reqs:null
		other_reqs:null
		pageSize:10
		my_hasPrev: false
		my_hasNext: false
		my_rangeStart: 0
		my_hasPrev: (->
			@get('my_rangeStart')
		).property 'my_rangeStart'
		my_prevPage: (->
			socket.emit 'moremyreqs', {skip:@get('my_rangeStart')-@get('pageSize')}, (reqs, theresmore)=>
				if reqs
					@set 'my_reqs', App.store.findMany(App.Request, reqs)
					@set 'my_hasNext', true
					@set 'my_rangeStart', @get('my_rangeStart') - @get('pageSize')
		)
		my_nextPage: (->
			socket.emit 'moremyreqs', {skip:@get('my_rangeStart')+@get('pageSize')}, (reqs, theresmore)=>
				if reqs
					@set 'my_reqs', App.store.findMany(App.Request, reqs)
					@set 'my_hasNext', theresmore
					@set 'my_rangeStart', @get('my_rangeStart') + @get('pageSize')
		)
		other_hasPrev: false
		other_hasNext: false
		other_rangeStart: 0
		other_hasPrev: (->
			@get('other_rangeStart')
		).property 'other_rangeStart'
		other_prevPage: (->
			socket.emit 'moreotherreqs', {skip:@get('other_rangeStart')-@get('pageSize')}, (reqs, theresmore)=>
				if reqs
					@set 'other_reqs', App.store.findMany(App.Request, reqs)
					@set 'other_hasNext', true
					@set 'other_rangeStart', @get('other_rangeStart') - @get('pageSize')
		)
		other_nextPage: (->
			socket.emit 'moreotherreqs', {skip:@get('other_rangeStart')+@get('pageSize')}, (reqs, theresmore)=>
				if reqs
					@set 'other_reqs', App.store.findMany(App.Request, reqs)
					@set 'other_hasNext', theresmore
					@set 'other_rangeStart', @get('other_rangeStart') + @get('pageSize')
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
			socket.emit 'pastreqs', (others, mine, oMore, mMore) =>
				if @get 'controller'	# in case we already switched out
					if mine then mine = App.store.findMany App.Request, mine
					if others then others = App.store.findMany App.Request, others
					@set 'controller.my_reqs', mine
					@set 'controller.other_reqs', others
					@set 'controller.my_hasNext', mMore
					@set 'controller.other_hasNext', oMore
