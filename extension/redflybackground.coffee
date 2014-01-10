
background =

	# the only real use of the background page is to juggle messages between content pages,
	# keeping track in local storage.
	# this is how we know which user to work with, and which redfly page we're on

	sendPage2LI: (setObj)->
		chrome.tabs.query {}, (tabs)->
			for t in tabs
				if t.url.indexOf(window.linkedURL) > 0					# for each linkedin tab
					chrome.tabs.sendMessage t.id, redfly:setObj			# send the new redfly navigation state

	loaded: ->
		chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
			###
			# read ('get') messages
			###

			# these are requests for data.
			if key = request.get
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
			

			###
			# write messages
			###

			# these 'tab' messages simply pass on from one content script to another
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
				background.sendPage2LI setObj
			false		# all done and done. don't bother replying.


###
# background page entry point
###

window.onload = ->

	background.loaded.bind(background)()									# setup message handling

	chrome.webNavigation.onHistoryStateUpdated.addListener (deets)->		# gets historystate events for redfly
		if not tab = deets?.tabId then return
		if not (url = deets?.url)?.length then return
		if (i =  url.indexOf(window.redflyURL)) < 0 then return			# so far we only need to do this for redfly
		url = url.substr(i + window.redflyURL.length + 1)				# (linkedin always refreshes: gmail might be hashes...)
		setObj = {}
		setObj["page_#{tab}"] = url											# save current redfly navigation to local storage
		chrome.storage.local.set setObj
		chrome.storage.local.get 'user', (data) ->
			if data?.user												# if there's no user,
				background.sendPage2LI.bind(background) setObj			# let the linkedin tabs know the new redfly state

