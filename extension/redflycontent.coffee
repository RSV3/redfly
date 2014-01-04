
# content

redflyURL = "10.0.0.2:5000"
gmailURL = "gmail.com"
linkedURL = "linkedin.com"


content =

	linkevents:
		save: (user, tab, id)->
			alert "save #{user} #{tab} #{id}"
			console.log "save #{user} #{tab} #{id}"
			false
		respond: (user, tab, id)->
			alert "respond #{user} #{tab} #{id}"
			console.log "respond #{user} #{tab} #{id}"
			false
		classify: (user, tab, id)->
			alert "classify #{user} #{tab} #{id}"
			console.log "classify #{user} #{tab} #{id}"
			false

	addButton: (name, user, tab, id) ->
		src = document.createElement 'div'
		src.className = 'redfly-action button-group-primary'
		src.innerHTML = "<input type='submit' name='#{name}' value='#{name} to Redfly' class='btn-action redfly-#{name}' />"
		dest = document.querySelector '#top-card .profile-actions'
		dest.parentNode.insertBefore src, dest
		src.addEventListener 'click', ->
			content.linkevents[name] user, tab, id
		, false


	scrapeThisPage: ->

	getLastLogin: (callback) ->
		if (cookies = document.cookie?.split ";")?.length
			cookies.forEach (cook) ->
				if (cook = cook?.split("="))?.length
					if cook[0] is 'lastlogin' then callback cook[1]
		callback null

	setupGmail: ->
		chrome.runtime.sendMessage {get: "user"}, (user) ->
			return unless user
			# one day we might want to add some redfly info to the compose panel
	
	# we load a content script on redfly in order to store the user and page
	setupRedfly: ->
		content.getLastLogin (lastlogin) ->
			return unless lastlogin
			data = user:lastlogin
			if (page = document.location.pathname) and page.length then data.page = page.substr 1
			chrome.runtime.sendMessage data

	setupLinked: ->
		if not document.location.pathname.match(/\/view/) then return
		chrome.runtime.sendMessage {get: "data"}, (parsedPages) ->
			if parsedPages.length
				for datum in parsedPages
					if datum.page.match 'request'
						return content.addButton 'respond', data.user, datum.tab, data["id_#{datum.tab}"]
				for datum in parsedPages
					if datum.page.match 'classify'
						return content.addButton 'classify', data.user, datum.tab, data["id_#{datum.tab}"]
				return content.addButton 'save', data.user, datum.tab, data["id_#{datum.tab}"]

	loaded: ->
		if document.location.href.match(new RegExp linkedURL) then return content.setupLinked()
		if document.location.href.match(new RegExp gmailURL) then return content.setupGmail()
		if document.location.href.match(new RegExp redflyURL) then return content.setupRedfly()
		console.log "error: unexpected content url #{document.location.href}"

window.onload = ->
	content.loaded.bind(content)()

