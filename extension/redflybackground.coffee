
# background

redflyURL = "10.0.0.2:5000"
gmailURL = "gmail.com"
linkedURL = "linkedin.com"


# the only real use of the background page is to juggle messages between content pages,
# keeping track in local storage.
# this is how we know which user to work with, and which redfly page we're on

scraper = loaded: ->
	chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
		if key = request.get
			if key is "data"			# get:'data' returns object with all stateful data
				chrome.storage.local.get null, (data)->			# get all local storage
					chrome.tabs.query {}, (tabs)->				# get all tabs
						parsedPages = []
						if data?.user							# return nothing if we don't know who the redfly user is
							for own key, val of data
								if key?.length
									keys = key.split '_'		# get all data of for 123_val where 123 is tab id and val is page, senderid
									if keys?.length is 2 and keys[0] is 'page' and tab = parseInt keys[1]
										tabfound = false
										for t in tabs
											if t.id is tab			# if the tab is still there,
												parsedPages.push {key:keys[0], tab:tab, page:val}
												tabfound = true
										unless tabfound then chrome.storage.local.remove key	# remove tab data if its no longer there
							parsedPages = parsedPages.sort (a,b) -> b.tab - a.tab
						console.dir parsedPages
						sendResponse parsedPages
			else						# get:'user' returns value of user
				chrome.storage.local.get key, (items) ->
					items = items[key] if items
					sendResponse items
			return true		# ^-- async: requires return true from addListener
		
		# fall thru to 'set' logic
		setObj = {}
		for key of request
			setObj[key] = request[key]
		setObj["id_#{sender.tab.id}"] = sender.id
		chrome.storage.local.set setObj
		false		# all done and done. don't bother replying.


window.onload = ->
	scraper.loaded.bind(scraper)()
	chrome.webNavigation.onHistoryStateUpdated.addListener (deets)->
		if not tab = deets?.tabId then return
		if not (url = deets?.url)?.length then return
		if (i =  url.indexOf(redflyURL)) < 0 then return
		url = url.substr(i + redflyURL.length + 1)
		setObj = {}
		setObj["page_#{tab}"] = url
		chrome.storage.local.set setObj

