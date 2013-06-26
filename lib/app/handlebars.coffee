module.exports = (Ember) ->

	Ember.Handlebars.registerBoundHelper 'plusOne', (value, options) ->
		if typeof value == 'string'
			value = parseInt value, 10
		1 + value

	Ember.Handlebars.registerBoundHelper 'format', (value, options) ->
		'' + value.getDate() + '-' + (value.getMonth() + 1) + '-' + value.getFullYear()

