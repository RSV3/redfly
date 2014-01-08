
content =

	linkevents:
		save: (user, tab, id)->
			data = {type:'save', url:window.location.href}
			chrome.runtime.sendMessage {tab:tab, data:data}
			false
		respond: (user, tab, id)->
			data = {type:'respond', url:window.location.href}
			chrome.runtime.sendMessage {tab:tab, data:data}
			false
		classify: (user, tab, id)->
			data = {type:'classify', url:window.location.href}
			chrome.runtime.sendMessage {tab:tab, data:data}
			false

	addButton: (name, user, tab, id) ->
		if removeme = document.querySelector '.rfaction' then removeme.parentNode.removeChild removeme
		src = document.createElement 'div'
		src.className = 'rfaction button-group-primary'
		src.innerHTML = "<input type='submit' name='#{name}' value='#{name} to Redfly' class='btn-action' style='float:right; margin:0.4em;' />"
		dest = document.querySelector '#top-card .profile-actions'
		dest.parentNode.insertBefore src, dest
		src.addEventListener 'click', ->
			content.linkevents[name] user, tab, id
			if removeme = document.querySelector '.rfaction' then removeme.parentNode.removeChild removeme
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
			if page = document.location.hash
				unless page.match(/respond/) or page.match(/classify/)
					page = null
			if not page and (page = document.location.pathname) and page.length then data.page = page.substr 1
			chrome.runtime.sendMessage data
		chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
			switch request?.type
				when 'respond'		# response
					if request.url
						alert 'responding with ' + request.url
				when 'classify'		# classifying
					if request.url
						evt = document.createEvent "CustomEvent"
						evt.initCustomEvent "classifyExtension", true, true, url:request.url
						document.dispatchEvent evt

				when 'save'		# regular scrape save
					if request.url
						alert 'scraping ' + request.url

	setupLinked: ->
		if not document.location.pathname.match(/\/view/) then return
		chrome.runtime.sendMessage {get: "data"}, (data) ->
			if data?.user and data.parsedPages.length
				# first try to match request/response
				for datum in data.parsedPages
					if datum.page.match 'respond'
						return content.addButton 'respond', data.user, datum.tab, datum.sender
				# then try to match classify
				for datum in data.parsedPages
					if datum.page.match 'classify'
						return content.addButton 'classify', data.user, datum.tab, datum.sender
				# otherwise, just save
				return content.addButton 'save', data.user, datum.tab, datum.sender

	loaded: ->
		if document.location.href.match(new RegExp window.linkedURL) then return content.setupLinked()
		if document.location.href.match(new RegExp window.gmailURL) then return content.setupGmail()
		if document.location.href.match(new RegExp window.redflyURL) then return content.setupRedfly()
		console.log "error: unexpected content url #{document.location.href}"

window.onload = ->
	content.loaded.bind(content)()

window.onhashchange = ->
	content.loaded.bind(content)()
