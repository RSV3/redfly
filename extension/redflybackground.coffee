bgPgObj =

	# the only real uses of the background page are:
	# to juggle messages between content pages,
	# and keeping track in local storage -
	#   this is how we know which user to work with, and which redfly page we're on

	# pass redfly page data to the linkedin tabs
	sendPage2LI: (setObj)->
		chrome.tabs.query {}, (tabs)->
			for t in tabs
				if t.url.indexOf(window.extURLs.linked) > 0					# for each linkedin tab
					chrome.tabs.sendMessage t.id, redfly:setObj			# send the new redfly navigation state


	# read ('get') messages
	handleRequest: (key, sendResponse)->
		if key is "data"			# get:'data' returns object with all stateful data
			chrome.storage.local.get null, (data)->			# get all local storage
				chrome.tabs.query {}, (tabs)->				# get all tabs
					parsedPages = []
					if data?.user							# return nothing if we don't know who the redfly user is
						for own key, val of data
							if key?.length
								tabfound = false
								keys = key.split '_'		# eg, page_123 has the page for tab with id 123
								if keys?.length is 2
									if keys[0] is 'page' and tab = parseInt keys[1]
										for t in tabs
											if t.id is tab			# if the tab is still there,
												parsedPages.push {tab:tab, page:val}
												tabfound = true
									delete data.key		# this will be re-saved on data in the parsedPages array
									unless tabfound then chrome.storage.local.remove key		# tidy up old tab data
						data.parsedPages = parsedPages.sort (a,b) -> b.tab - a.tab		# sort by most recent tab first
					sendResponse data
		else
			# also allow convenience of requesting a single value
			# eg, get:'user' returns value of user
			chrome.storage.local.get key, (items) ->
				items = items[key] if items
				sendResponse items
		return true		# ^-- storage interface is async: requires return true from addListener
	
	loaded: ->
		# there are three types of messages: 'get', 'set' and 'tab'
		chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->

			# 'get' messages are requests for data.
			if key = request.get then return bgPgObj.handleRequest key, sendResponse		# the handleR will reply

			# 'tab' messages simply pass on from one content script to another
			# so far, we only use these to send a message from linkedin to redfly
			if request.tab
				chrome.tabs.sendMessage request.tab, request.data
				return false		# all done and done. don't bother replying.

			# if its not a 'tab' write message, or a 'get' read message, simply fall thru to 'set' logic
			# currently, this is just redfly setting user and page details
			setObj = {}
			if request.user then setObj.user = request.user
			if request.page and sender?.tab?.id then setObj["page_#{sender.tab.id}"] = request.page
			chrome.storage.local.set setObj
			if request.page
				delete setObj.user
				bgPgObj.sendPage2LI setObj
			false		# all done and done. don't bother replying.


###
# background page entry point
###

window.onload = ->

	bgPgObj.loaded.bind(bgPgObj)()									# setup message handling

	chrome.webNavigation.onHistoryStateUpdated.addListener (deets)->		# gets historystate events for redfly
		if not tab = deets?.tabId then return
		if not (url = deets?.url)?.length then return
		if (i =  url.indexOf(window.extURLs.redfly)) < 0 then return			# so far we only need to do this for redfly
		url = url.substr(i + window.extURLs.redfly.length + 1)				# (linkedin always refreshes: gmail might be hashes...)
		setObj = {}
		setObj["page_#{tab}"] = url											# save current redfly navigation to local storage
		chrome.storage.local.set setObj
		chrome.storage.local.get 'user', (data) ->
			if data?.user												# if there's no user,
				bgPgObj.sendPage2LI.bind(bgPgObj) setObj			# let the linkedin tabs know the new redfly state


chrome.runtime.onInstalled.addListener (details)->
	doEachTab = (tabs, operate, done)->
		if not tabs?.length then return done()
		if not t = tabs.shift() then return doEachTab tabs, operate, done
		operate t, ->
			doEachTab tabs, operate, done
	doEachWindow = (windows, operate, done)->
		if not windows?.length then return done()
		if not w = windows.shift() then return doEachWindow windows, operate, done
		doEachTab w.tabs, operate, ->
			doEachWindow windows, operate, done

	chrome.windows.getAll {populate:true}, (windows)->
		doEachWindow windows, (t, done)->
			unless t.url.match(window.extURLs.redfly) then return done()
			chrome.tabs.executeScript t.id, {file:'extconf.js'}, ->
				chrome.tabs.executeScript t.id, {code:'window.runningOnInstallation=true;'}, ->
					chrome.tabs.executeScript t.id, {file:'redflycontent.js'}, ->
						done()
		, ->
			chrome.windows.getAll {populate:true}, (windows)->
				doEachWindow windows, (t, done)->
					unless t.url.match(window.extURLs.linked) then return done()
					chrome.tabs.executeScript t.id, {file:'extconf.js'}, ->
						chrome.tabs.executeScript t.id, {code:'window.runningOnInstallation=true;'}, ->
							chrome.tabs.executeScript t.id, {file:'linkedcontent.js'}, ->
								done()
				, ->
					console.log "plugin installed: initialised all tabs and windows"
