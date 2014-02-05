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

		other_reqs:null
		other_pageSize:0
		other_hasPrev: false
		other_hasNext: false
		other_rangeStart: 0
		other_hasPrev: (->
			@get('other_rangeStart')
		).property 'other_rangeStart'

		clear: (which)->
			@set "#{which}_reqs", null
			@set "#{which}_pageSize", 0
			@set "#{which}_hasNext", false
			@set "#{which}_rangeStart", 0

		goNextPage: (which)->
			socket.emit 'requests', {old:true, skip:@get("#{which}_rangeStart")+@get("#{which}_pageSize")}, (reqs, theresmore)=>
				if not reqs then return
				@set "#{which}_reqs", @store.find 'request', reqs
				@set "#{which}_hasNext", theresmore
				@set "#{which}_rangeStart", @get("#{which}_rangeStart") + @get("#{which}_pageSize")

		goPrevPage: (which)->
			socket.emit 'requests', {old:true, skip:@get("#{which}_rangeStart")-@get("#{which}_pageSize")}, (reqs, theresmore)=>
				if not reqs then return
				@set "#{which}_reqs", @store.find 'request', reqs
				@set "#{which}_hasNext", true
				@set "#{which}_rangeStart", @get("#{which}_rangeStart") - @get("#{which}_pageSize")

	App.PastreqsView = Ember.View.extend
		template: require '../../../../templates/sidebars/pastreqs.jade'
		classNames: ['pastreqs']
		selectTab: (ev)->
			@closeModal()
			@$().find(".nav-tabs .active").removeClass 'active'
			@$().find(".nav-tabs .#{ev}").addClass 'active'
			@$().find(".tab-content .tab-pane.active").removeClass 'active'
			@$().find(".tab-content .tab-pane.#{ev}").addClass 'active'
		closeModal: (->
			$c = @get 'controller'
			@$('.thisReq').removeClass('myLightSpeedIn').addClass('animated myLightSpeedOut')
			Ember.run.later this, ->
				$c.set 'showthisreq', null
			, 500
		)
		idsme: false
		prevPage: (which)->
			@closeModal()
			@get('controller').goPrevPage which
		nextPage: (which)->
			@closeModal()
			@get('controller').goNextPage which
		willDestroyElement: ->
			@closeModal()
		didInsertElement: ->
			@get('controller').clear "other"
			@get('controller').clear "my"
			socket.emit 'requests', {old:true}, (reqs, theresmore) =>
				if @get 'controller'	# in case we already switched out
					@set 'controller.other_hasNext', theresmore
					if theresmore then @set 'controller.other_pageSize', reqs.length
					console.log "got #{reqs?.length} other old requests to list ..."
					if reqs then reqs = @store.find 'request', reqs
					@set 'controller.other_reqs', reqs
					socket.emit 'requests', {old:true, me:true}, (reqs, theresmore) =>
						if @get 'controller'	# in case we already switched out
							@set 'controller.my_hasNext', theresmore
							if theresmore then @set 'controller.my_pageSize', reqs.length
							console.log "got #{reqs?.length} of our own old requests to list ..."
							if reqs then reqs = @store.find 'request', reqs
							@set 'controller.my_reqs', reqs
