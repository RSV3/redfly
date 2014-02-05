module.exports = (Ember, App, socket) ->

	App.LeadersController = Ember.Controller.extend
		sortProperties: ['name']
		lowest: 0
		leader: []
		laggard: []

	App.LeaduserView = App.HoveruserView.extend
		template: require '../../../../templates/components/leaduser.jade'

	App.LeadersView = Ember.View.extend
		template: require '../../../../templates/sidebars/leaders.jade'
		classNames: ['leaders']
		leaduserView: App.LeaduserView.extend()
		didInsertElement: ->
			store = @get('controller').store
			socket.emit 'leaderboard', (day, lowest, leaders, laggards) =>
				if @get 'controller'	# in case we already switched out
					@set 'controller.lowest', lowest
					@set 'controller.leader', store.find 'user', leaders
					@set 'controller.laggard', store.find 'user', laggards
