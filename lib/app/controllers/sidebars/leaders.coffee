module.exports = (Ember, App, socket) ->

	App.LeadersController = Ember.Controller.extend
		sortProperties: ['name']
		lowest: 0
		leader: []
		laggard: []

	App.LeadersView = Ember.View.extend
		template: require '../../../../templates/sidebars/leaders'
		classNames: ['leaders']
		didInsertElement: ->
			socket.emit 'leaderboard', (lowest, leaders, laggards) =>
				@set 'controller.lowest', lowest
				@set 'controller.leader', App.store.findMany(App.User, leaders)
				@set 'controller.laggard', App.store.findMany(App.User, laggards)

