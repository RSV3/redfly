linkedContentObj =

	# scrape linkedin view page data
	scrape: (deets)->
		deets.specialties = []
		deets.positions = []
		deets.companies = []
		if profile = document.getElementById 'profile'
			if el = profile.querySelector '.profile-picture img' then deets.pictureUrl = el.src
			if el = profile.querySelector 'span.full-name' then deets.name = el.firstChild.nodeValue

			if el = profile.querySelector '.public-profile span' then deets.publicProfileUrl = el.firstChild.nodeValue

			if els = profile.querySelectorAll 'ul.skills-section li'
				for el in els
					if name = el.querySelector 'span.endorse-item-name a'
						deets.specialties.push name.firstChild.nodeValue
			else if els = profile.querySelectorAll 'ol.skills li'
				for el in els
					deets.specialties.push el.firstChild.nodeValue

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
			data = type:'save'
			linkedContentObj.scrape data
			data.publicProfileUrl ?= window.location.href
			chrome.runtime.sendMessage {tab:tab, data:data}
			false
		respond: (tab)->
			data = type:'respond'
			linkedContentObj.scrape data
			data.publicProfileUrl ?= window.location.href
			chrome.runtime.sendMessage {tab:tab, data:data}
			false
		classify: (tab)->
			data = type:'classify'
			linkedContentObj.scrape data
			data.publicProfileUrl ?= window.location.href
			chrome.runtime.sendMessage {tab:tab, data:data}
			false

	# draw the appropriate button on the linkedin tab
	addButton: (name, tab) ->
		if removeme = document.querySelector('.rfaction') then removeme.parentNode.removeChild removeme
		src = document.createElement 'div'
		src.className = 'rfaction button-group-primary'
		src.innerHTML = "<input type='submit' name='#{name}' value='#{name} to Redfly' class='btn-action' style='float:right; margin:0.4em;' />"
		dest = document.querySelector '#top-card .profile-actions'
		dest.parentNode.insertBefore src, dest
		src.addEventListener 'click', ->
			linkedContentObj.linkevents[name] tab
			if hideMe = document.querySelector('.rfaction') then hideMe.style.display = 'none'
		, false

	# replace the button on the linkedin tab - unless it's hidden
	replaceButton: (name, tab) ->
		# don't add (replace) the button if its already there and hidden
		if (replaceMe = document.querySelector '.rfaction') and replaceMe.style.display is 'none' then return false
		linkedContentObj.addButton name, tab


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
						return linkedContentObj.addButton 'respond', datum.tab
				# then try to match classify
				for datum in data.parsedPages
					if datum.page.match 'classify'
						return linkedContentObj.addButton 'classify', datum.tab
				# otherwise, just save
				return linkedContentObj.addButton 'save', datum.tab

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
				if val.match 'respond' then return linkedContentObj.replaceButton 'respond', key
				if val.match 'classify' then return linkedContentObj.replaceButton 'classify', key
				return linkedContentObj.replaceButton 'save', key


# whenever a matching content tab is first loaded:
window.onload = ->
	if document.location.href.match(new RegExp window.extURLs.linked) then return linkedContentObj.setupLinked.bind(linkedContentObj)()
	console.log "error: unexpected content url #{document.location.href} in linkedincontent script"

if window.runningOnInstallation then linkedContentObj.setupLinked.bind(linkedContentObj)()

