module.exports = (Ember, App) ->

	App.SocialView = Ember.View.extend
		prefixes: (->
				linkedin: 'www.linkedin.com/'							# some linkedin IDs use nice /in/ pages
				customlinkedin: 'www.linkedin.com/in/'					# some linkedin IDs use nice /in/ pages
				uglylinkedin: 'www.linkedin.com/pub/'					# users without custom urls have these ugly ones
				privatelinkedin: 'www.linkedin.com/profile/view?id='	# private linkedin IDs use ugly numberplate ?id=
				twitter: 'twitter.com/'
				facebook: 'www.facebook.com/'
			).property()
		guessPattern: (network, id)->
			if network isnt 'linkedin' then return network
			prefix = @get('prefixes')['linkedin']
			if (i = id.indexOf(prefix)) >= 0 then id = id[i+prefix.length..]
			if id?.match(/^((((\/)?profile\/)?view\?)?id=)?[0-9]*$/)?.length then return 'privatelinkedin'										
			if id?.match(/^(((\/)?in)?\/)?[\w]*$/)?.length then return 'customlinkedin'
			if id?.match(/^(((\/)?pub)?\/)?.*\/.*/)?.length then return 'uglylinkedin'
			console.log "socialView:guessPattern failed to match #{id}"
			return null
		simplifyID: (patternName, id)->
			switch patternName
				when 'customlinkedin'
					if (i = id.indexOf('in/')) >= 0 then id = id[i+3..]
				when 'uglylinkedin'
					if (i = id.indexOf('pub/')) >= 0 then id = id[i+4..]
				when 'privatelinkedin'
					if (i = id.indexOf('id=')) >= 0 then id = id[i+3..]
			id
		_open: (name) ->
			if (id = @get "controller.#{name}")
				name = @guessPattern name, id
				window.open "http://#{@get('prefixes')[name]}#{id}"
		openFacebook: ->
			@_open 'facebook'
		openLinkedin: ->
			@_open 'linkedin'
		openTwitter: ->
			@_open 'twitter'
