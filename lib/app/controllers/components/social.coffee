module.exports = (Ember, App, socket) ->

	App.SocialView = Ember.View.extend
		prefixes: (->
				linkedin: 'www.linkedin.com/profile/view?id='
				twitter: 'twitter.com/'
				facebook: 'www.facebook.com/'
			).property()
		_open: (name) ->
			if network = @get('controller.' + name)
				window.open 'http://' + @get('prefixes')[name] + network
		openFacebook: ->
			@_open 'facebook'
		openLinkedin: ->
			@_open 'linkedin'
		openTwitter: ->
			@_open 'twitter'
