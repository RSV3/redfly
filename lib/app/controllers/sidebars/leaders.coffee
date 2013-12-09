module.exports = (Ember, App, socket) ->

	App.LeadersController = Ember.Controller.extend
		sortProperties: ['name']
		lowest: 0
		leader: []
		laggard: []

	App.LeaduserView = App.HoveruserView.extend
		template: require '../../../templates/components/leaduser'

	App.LeadersView = Ember.View.extend
		template: require '../../../../templates/sidebars/leaders'
		classNames: ['leaders']
		leaduserView: App.LeaduserView.extend()
		didInsertElement: ->
			socket.emit 'leaderboard', (day, lowest, leaders, laggards) =>
				if @get 'controller'	# in case we already switched out
					@set 'controller.lowest', lowest
					@set 'controller.leader', App.store.findMany(App.User, leaders)
					@set 'controller.laggard', App.store.findMany(App.User, laggards)
