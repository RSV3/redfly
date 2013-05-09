module.exports = (Ember, App, socket) ->

	App.SocialView = Ember.View.extend
		prefixes: (->
				altlinkedin: 'www.linkedin.com/in/'					# some linkedin IDs use nice /in/ pages
				linkedin: 'www.linkedin.com/profile/view?id='		# most linkedin IDs use ugly numberplate ?id=
				twitter: 'twitter.com/'
				facebook: 'www.facebook.com/'
			).property()
		_open: (name) ->
			if (id = @get "controller.#{name}")
				if name is 'linkedin' and not id?.match(/^[0-9]*$/)?.length	
					name = 'altlinkedin'										
				window.open "http://#{@get('prefixes')[name]}#{id}"
		openFacebook: ->
			@_open 'facebook'
		openLinkedin: ->
			@_open 'linkedin'
		openTwitter: ->
			@_open 'twitter'
