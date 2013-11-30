module.exports = (Ember, App, socket) ->

	App.HoveruserView = Ember.View.extend
		expanded: false
		classNames: ['hoveruser']
		hoverpro: ->
			@set 'expanded', not @get 'expanded'
			console.log 'returning from hoverpro'
			false

