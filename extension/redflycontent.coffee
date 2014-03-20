
###
# keep as much as possible safely tucked away here in a content object
###

redflyContentObj =

	# return the lastlogin cookie from redfly
	getLastLogin: (callback) ->
		if (cookies = document.cookie?.split ";")?.length
			cookies.forEach (cook) ->
				if (cook = cook?.split("="))?.length
					if cook[0] is 'lastlogin' then callback cook[1]
		callback null


	# sometimes redfly communicates state using hash, in addition to history state
	# either way, we want to keep track of the page (be it state/hash)

	refreshRedfly: ->
		redflyContentObj.getLastLogin (lastlogin) ->
			return unless lastlogin
			data = user:lastlogin
			if page = document.location.hash
				unless page.match(/respond/) or page.match(/classify/)		# ignore hash except for respond and classify
					page = null
			if not page then page = document.location.pathname
			if page?.length then data.page = page.substr 1
			chrome.runtime.sendMessage data

	loadedRedfly: ->
		flag = document.createElement 'div'						# add a dummy div to note that we're loaded
		flag.className = 'redfly-flag-extension-is-loaded'
		dest = document.querySelector('body').firstChild
		dest.parentNode.insertBefore flag, dest
		if evt = document.createEvent "CustomEvent"				# and send an event to this tab to remove any install links
			evt.initCustomEvent "installExtension", true, true, null


	###
	# on page load,
	# 1. alert parent tab (hide install links
	# 2. send current state to background page
	# 3. listen for commands from linkedin (which are sent via background page)
	###

	setupRedfly: ->
		redflyContentObj.loadedRedfly()		# alert the parent tab that script is loaded
		redflyContentObj.refreshRedfly()		# get current state, and send to background page for local storage

		chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->		# listen for messsage from background page
			switch request?.type													# (which actually originate from linkedin tabs)
				when 'respond'		# response
					if request.publicProfileUrl
						if evt = document.createEvent "CustomEvent"
							evt.initCustomEvent "respondExtension", true, true, request
				when 'classify'		# classifying
					if request.publicProfileUrl
						if evt = document.createEvent "CustomEvent"
							evt.initCustomEvent "classifyExtension", true, true, request
				when 'save'		# regular scrape save
					if request.publicProfileUrl
						if evt = document.createEvent "CustomEvent"
							evt.initCustomEvent "saveExtension", true, true, request
			if evt then document.dispatchEvent evt


###
# entry points
###

# whenever a matching content tab is first loaded:
window.onload = ->
	if document.location.href.match(new RegExp window.extURLs.redfly) then return redflyContentObj.setupRedfly.bind(redflyContentObj)()
	console.log "error: unexpected onload url #{document.location.href} in redflycontent script"

# whenever hash changes:
window.onhashchange = ->
	if document.location.href.match(new RegExp window.extURLs.redfly) then return redflyContentObj.refreshRedfly.bind(redflyContentObj)()
	console.log "error: unexpected hashchange url #{document.location.href} in redflycontent script"

if window.runningOnInstallation then redflyContentObj.setupRedfly.bind(redflyContentObj)()

