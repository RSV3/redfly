module.exports = (Ember, App, socket) ->


	App.LeaderboardController = Ember.Controller.extend
		sortProperties: ['name']

	App.LeaderboardView = Ember.View.extend
		template: require '../../../templates/leaderboard'
		# classNames: ['leaderboard']
