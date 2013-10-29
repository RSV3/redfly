module.exports = (Ember, App, socket) ->

	App.PastreqsController = Ember.Controller.extend
		my_reqs:null
		other_reqs:null

	App.PastreqsView = Ember.View.extend
		template: require '../../../../templates/sidebars/pastreqs'
		classNames: ['pastreqs']
		didInsertElement: ->
			socket.emit 'pastreqs', (mine, others) =>
				if @get 'controller'	# in case we already switched out
					@set 'controller.my_reqs', App.store.findMany App.Request, mine
					@set 'controller.other_reqs', App.store.findMany App.Request, others
