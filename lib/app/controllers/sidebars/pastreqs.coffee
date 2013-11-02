module.exports = (Ember, App, socket) ->

	App.PastreqsController = Ember.Controller.extend
		my_reqs:null
		other_reqs:null

	App.PastreqsView = Ember.View.extend
		template: require '../../../../templates/sidebars/pastreqs'
		classNames: ['pastreqs']
		selectTab: (ev)->
			@$().find(".nav-tabs .active").removeClass 'active'
			@$().find(".nav-tabs .#{ev}").addClass 'active'
			@$().find(".tab-content .tab-pane.active").removeClass 'active'
			@$().find(".tab-content .tab-pane.#{ev}").addClass 'active'
		didInsertElement: ->
			socket.emit 'pastreqs', (mine, others) =>
				if @get 'controller'	# in case we already switched out
					if mine then mine = App.store.findMany App.Request, mine
					if others then others = App.store.findMany App.Request, others
					@set 'controller.my_reqs', mine
					@set 'controller.other_reqs', others
