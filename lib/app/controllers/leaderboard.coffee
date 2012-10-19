module.exports = (Ember, App, socket) ->


	App.LeaderboardController = Ember.ArrayController.extend()
	
	App.LeaderboardView = Ember.View.extend
		template: require '../../../views/templates/leaderboard'
		# classNames: ['leaderboard']
