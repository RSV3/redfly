
content =

	# scrape linkedin view page data
	scrape: (deets)->
		deets.specialities = []
		deets.positions = []
		deets.companies = []
		if profile = document.getElementById 'profile'
			if el = profile.querySelector '.profile-picture img' then deets.pictureUrl = el.src
			if el = profile.querySelector 'span.full-name' then deets.name = el.firstChild.nodeValue

			if els = profile.querySelectorAll 'ul.skills-section li'
				for el in els
					if name = el.querySelector 'span.endorse-item-name a'
						deets.specialities.push name.firstChild.nodeValue
			else if els = profile.querySelectorAll 'ol.skills li'
				for el in els
					deets.specialities.push el.firstChild.nodeValue

			position = company = null
			if el = profile.querySelector '.background-experience'
				if els = el.querySelectorAll 'header'
					for el in els
						position = el.querySelector 'h4 a'
						company = el.querySelector 'h5 span a'
						if position or company
							deets.positions.push position?.innerText
							deets.companies.push company?.innerText
			else if els = profile.querySelectorAll '.position'
				for el in els
					position = el.querySelector 'h3 span.title'
					company = el.querySelector 'h4 span.org'
					if position or company
						deets.positions.push position?.nodeValue
						deets.companies.push company?.nodeValue

	# send data from linkedin tab to background page
	linkevents:
		save: (tab)->
			data = {type:'save', url:window.location.href}
			content.scrape data
			chrome.runtime.sendMessage {tab:tab, data:data}
			false
		respond: (tab)->
			data = {type:'respond', url:window.location.href}
			chrome.runtime.sendMessage {tab:tab, data:data}
			false
		classify: (tab)->
			data = {type:'classify', url:window.location.href}
			content.scrape data
			chrome.runtime.sendMessage {tab:tab, data:data}
			false

	# draw the appropriate button on the linkedin tab
	addButton: (name, tab) ->
		if removeme = document.querySelector '.rfaction' then removeme.parentNode.removeChild removeme
		src = document.createElement 'div'
		src.className = 'rfaction button-group-primary'
		src.innerHTML = "<input type='submit' name='#{name}' value='#{name} to Redfly' class='btn-action' style='float:right; margin:0.4em;' />"
		dest = document.querySelector '#top-card .profile-actions'
		dest.parentNode.insertBefore src, dest
		src.addEventListener 'click', ->
			content.linkevents[name] tab
			if removeme = document.querySelector '.rfaction' then removeme.parentNode.removeChild removeme
		, false

	# replace the button on the linkedin tab - only if it's there.
	replaceButton: (name, tab) ->
		if removeme = document.querySelector '.rfaction' then removeme.parentNode.removeChild removeme
		else return false
		src = document.createElement 'div'
		src.className = 'rfaction button-group-primary'
		src.innerHTML = "<input type='submit' name='#{name}' value='#{name} to Redfly' class='btn-action' style='float:right; margin:0.4em;' />"
		dest = document.querySelector '#top-card .profile-actions'
		dest.parentNode.insertBefore src, dest
		src.addEventListener 'click', ->
			content.linkevents[name] tab
			if removeme = document.querySelector '.rfaction' then removeme.parentNode.removeChild removeme
		, false


	# return the lastlogin cookie from redfly
	getLastLogin: (callback) ->
		if (cookies = document.cookie?.split ";")?.length
			cookies.forEach (cook) ->
				if (cook = cook?.split("="))?.length
					if cook[0] is 'lastlogin' then callback cook[1]
		callback null



	###
	# we might load a content script on gmail in order to give insight on the compose pane,
	# and maybe even pre-empt nudge.
	# but not yet ...
	###

	setupGmail: ->
		chrome.runtime.sendMessage {get: "user"}, (user) ->
			return unless user
			# one day we might want to add some redfly info to the compose panel
	
	refreshGmail: ->
		return false



	###
	# we load a content script on redfly in order to store the user and page
	###

	# sometimes redfly communicates state using hash, in addition to history state
	# either way, we want to keep track of the page (be it state/hash)

	refreshRedfly: ->
		content.getLastLogin (lastlogin) ->
			return unless lastlogin
			data = user:lastlogin
			if page = document.location.hash
				unless page.match(/respond/) or page.match(/classify/)		# ignore hash except for respond and classify
					page = null
			if not page then page = document.location.pathname
			if page?.length then data.page = page.substr 1
			chrome.runtime.sendMessage data

	setupRedfly: ->
		content.refreshRedfly()
		# messages come to the redfly tab from the linkedin tab via the background page
		chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
			switch request?.type
				when 'respond'		# response
					if request.url
						if evt = document.createEvent "CustomEvent"
							evt.initCustomEvent "respondExtension", true, true, request
				when 'classify'		# classifying
					if request.url
						if evt = document.createEvent "CustomEvent"
							evt.initCustomEvent "classifyExtension", true, true, request
				when 'save'		# regular scrape save
					if request.url
						if evt = document.createEvent "CustomEvent"
							evt.initCustomEvent "saveExtension", true, true, request
			if evt
				document.dispatchEvent evt



	###
	# we load a content script on linkedin to setup redfly action buttons on the connection view pages
	###

	setupLinked: ->
		# to be sure, to be sure: we only really care about connection view pages
		if not document.location.pathname.match(/\/view/) then return

		# when linkedin tab opens, request all redfly data from the extension's background page
		chrome.runtime.sendMessage {get: "data"}, (data) ->
			if data?.user and data.parsedPages.length
				# first try to match request/response
				for datum in data.parsedPages
					if datum.page.match 'respond'
						return content.addButton 'respond', datum.tab
				# then try to match classify
				for datum in data.parsedPages
					if datum.page.match 'classify'
						return content.addButton 'classify', datum.tab
				# otherwise, just save
				return content.addButton 'save', datum.tab

		chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
			unless data = request.redfly
				console.log "unexpected message to linkedin:"
				console.dir request
				return false
			for own key,val of data
				if key then key = key.split '_'
				if key?.length and key[0] is 'page' then key = parseInt key[1]
				else key = null
				unless key
					console.log "invalid message to linkedin:"
					console.dir data
					return false
				if val.match 'respond' then return content.replaceButton 'respond', key
				if val.match 'classify' then return content.replaceButton 'classify', key
				return content.replaceButton 'save', key

	refreshLinked: ->
		return false			# actually, I don't think linkedin uses hash ...



# entry points


# whenever a matching content tab is first loaded:

window.onload = ->
	if document.location.href.match(new RegExp window.linkedURL) then return content.setupLinked.bind(content)()
	if document.location.href.match(new RegExp window.gmailURL) then return content.setupGmail.bind(content)()
	if document.location.href.match(new RegExp window.redflyURL) then return content.setupRedfly.bind(content)()
	console.log "error: unexpected content url #{document.location.href}"


# whenever hash changes:

window.onhashchange = ->
	if document.location.href.match(new RegExp window.linkedURL) then return content.refreshLinked()
	if document.location.href.match(new RegExp window.gmailURL) then return content.refreshGmail()
	if document.location.href.match(new RegExp window.redflyURL) then return content.refreshRedfly()
	console.log "error: unexpected content url #{document.location.href}"

