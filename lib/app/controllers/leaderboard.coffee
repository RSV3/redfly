module.exports = (Ember, App, socket) ->


	App.LeaderboardController = Ember.ArrayController.extend
		sortProperties: ['name']
	
	App.LeaderboardView = Ember.View.extend
		template: require '../../../views/templates/leaderboard'
		# classNames: ['leaderboard']
