module.exports = (Ember, App)->
	util = require '../util.coffee'
	socketemit = require '../socketemit.coffee'
	_ = require 'underscore'
	moment = require 'moment'

	App.RequestsController = Ember.ObjectController.extend
		hasNext: false
		rangeStart: 0
		rangeStop: (->
			@get('rangeStart') + @get('reqs.length')
		).property 'rangeStart', 'reqs.@each'
		hasPrev: (->
			@get('rangeStart')
		).property 'rangeStart'
		pageSize:0
		reqs:null
		newreq:null
		newdate:null
		urgent: false
		prevPage: (->
			socketemit.get 'listrequests', {skip:@get('rangeStart')-@get('pageSize')}, (reqs, theresmore)=>
				if reqs
					@set 'reqs', @store.find 'request', reqs
					@set 'hasNext', true
					@set 'rangeStart', @get('rangeStart') - @get('pageSize')
		)
		nextPage: (->
			socketemit.get 'listrequests', {skip:@get('rangeStart')+@get('pageSize')}, (reqs, theresmore)=>
				if reqs
					@set 'reqs', @store.find 'request', reqs
					@set 'hasNext', theresmore
					@set 'rangeStart', @get('rangeStart') + @get('pageSize')
		)
		add: (->
			if note = util.trim @get('newreq')
				# we used to have set expiry to future a date, ie: new Date @get('newdate') or moment().add(7, 'days')
				# now, we start with a record with no expiry, then set it when the request is ended.
				nuReq =
					user: App.user
					urgent: @get 'urgent'
					text: note
					response: []
				@store.createRecord('request', nuReq).save().then =>
					@reloadFirstPage()
				@set 'newreq', null
				@set 'newdate', null
				@set 'urgent', null
		)
		reloadFirstPage: (->
			socketemit.get 'listrequests', (reqs, theresmore)=>
				@set 'reqs', @store.find 'request', reqs
				@set 'hasNext', theresmore
		)
		disableAdd: (->
			not @get('newreq')?.length
		).property 'newreq'

	App.RequestsView = Ember.View.extend
		template: require '../../../templates/requests.jade'
		classNames: ['requests']
		toggleUrgency: (->
			@set 'controller.urgent', not @get 'controller.urgent'
		)
		newReqView: Ember.TextArea.extend
			classNames: ['col-md-12']
			placeholder: 'Who are you looking for in detail? Please write 2 or 3 lines on what value you can also provide them?'
			rows: 5
			tabindex: 1

		didInsertElement: ->
			###
			# SOCKET.IO LOSS: we can't easily do this without socket.io
			#socket.on 'feed', (data) =>
				store = @get('controller').store
				if not data or data.type isnt 'Request' or not data.id then return
				Ember.run.next this, ->
					if data.response?.length	# update
						request = store.find('request', data.id).then ->
							responses = request.get 'response'
							new_resp = _.without data.response, responses.getEach('id')
							_.each new_resp, (r)-> responses.addObject store.find 'response', r
							Ember.run.next this, ->
								request.get('stateManager').send 'becameClean'
					else
						if @get 'controller.rangeStart' then return		# dont try to show new request if we're on another page
						if not @get 'controller.rangeStop' then return	# and dont bother if there's no shown
						@get('controller').reloadFirstPage()
			###

	App.RequestController = Ember.ObjectController.extend
		hovering: null
		hoverable: (->
			if @get('response.length') then 'hoverable' else 'nothoverable'
		).property 'response.@each'
		###
		# we used to display the date when the request was scheduled to expire ...
		#
		expires: (->
			if expireswhen = @get('expiry') then moment(expireswhen).fromNow()
		).property 'expiry'
		###
		disabled: (->
			if @get('user')?.get('id') is App.user.id then "disabled"
		).property 'user'
		addNote: (note) ->
			self = @
			@store.createRecord('response',
				user: App.user
				body: note
			).save().then ->
				self.get('response').pushObject newnote
				self.get('response').save()
		addSuggestions: (suggestions)->
			suggestion = @store.createRecord 'response',
				user: App.user
				contact: []
			_.each suggestions, (r)-> suggestion.get('contact').pushObject r
			suggestion.save().then ->
				self.get('response').pushObject suggestion
				self.get('response').save()

	App.RequserView = App.HoveruserView.extend
		template: require '../../../templates/components/requser.jade'

	App.RespuserView = App.HoveruserView.extend
		template: require '../../../templates/components/respuser.jade'

	App.RequestView = Ember.View.extend
		selectedSearchContacts: (->
			if @get('selectedOption') isnt 'Redfly Contact' then return false
			location.hash = ''
			true
		).property 'selectedOption'
		selectedSuggestLink: (->
			if @get('selectedOption') isnt 'Linkedin Link' then return false
			location.hash = 'respond'
			# setup handler for linkedin response
			@$(document).off 'respondExtension'					# never quite sure if it's already been set ...
			@$(document).on 'respondExtension', (ev)=>
				if (ev = ev?.originalEvent?.detail) and @get 'selectedSuggestLink'
					if ev.publicProfileUrl then @set 'newnote', ev.publicProfileUrl
				false
			true
		).property 'selectedOption'
		selectedAddNote: (->
			if @get('selectedOption') isnt 'Message' then return false
			location.hash = ''
			true
		).property 'selectedOption'
		selectedOption: "Redfly Contact"
		selectOptions: ["Redfly Contact", "Linkedin Link", "Message"]
		expanded: false
		selections:[]
		newnote:''
		idsme: (->
			@get('controller.user.id') is App.user.get('id')
		).property 'controller.user'
		saveSuggestions: (->
			if @get 'selectedSearchContacts' then return not @get('selections').length
			if @get 'selectedAddNote' then return not @get('newnote').length
			return not util.isLIURL @get('newnote')
		).property 'selections.@each', 'newnote', 'selectedSearchContacts', 'selectedAddNote'
		showold: (->
			if @get 'suggesting' then return
			@get('controller').transitionToRoute 'responses', @get 'controller.id'
			###
			if @get('controller.response.length') then it = @get('controller.content')
			else it = null
			@set 'parentView.idsme', App.user.get('id') is it?.get('user.id')
			@set 'parentView.controller.showthisreq', it
			Ember.run.next this, ->
				@get('parentView').$('.thisReq').removeClass('myLightSpeedOut').addClass('animated myLightSpeedIn')
			###
		)
		toggle: (->
			if @get 'suggesting' then return
			if not @get('controller.response.length') then return
			@set 'expanded', not @get 'expanded'
		)
		clear: (->
			@set 'selections', []
			@set 'newnote', ''
			location.hash = ''
		)
		cancel: (->
			@clear()
			@set 'suggesting', false
		)
		suggest: (->
			if @get('controller.disabled') then return
			@clear()
			@set 'suggesting', true
		)
		expire: (->
			@set 'controller.expiry', new Date()		# used to be a future date: now set it to today when user ends request
			@get('controller.content').save()
		)
		addResponse: (->
			if @get('selectedSearchContacts') then @get('controller').addSuggestions @get 'selections'
			else @get('controller').addNote @get 'newnote'
			@cancel()
			@set 'expanded', true
		)
		reqUserView: App.RequserView.extend()
		leaveLinkView: Ember.TextArea.extend
			classNames: ['col-md-12']
			placeholder: 'Paste Linkedin url'
			rows: 1
		newNoteView: Ember.TextArea.extend
			classNames: ['col-md-12']
			placeholder: 'Leave a message'
			rows: 1
		responseSearchView: App.SearchView.extend
			classNames: ['col-md-12']
			prefix: 'contact:'
			conditions: (->
				addedBy: App.user.get 'id'
			).property()
			excludes: (->
				contacts = @get('parentView.controller.response').getEach('contact')
				ids = @get('parentView.selections').getEach('id')
				_.each contacts, (c)-> ids = ids.concat c.getEach 'id'
				ids
			).property 'controller.content', 'parentView.selections.@each'
			select: (context) ->
				$('div.search.dropdown').blur()
				@get('parentView.selections').addObject @get('parentView.controller').store.find 'contact', context.id
			keyUp: (event) -> false
			submit: -> false
		willDestroyElement: (->
			@$(document).off 'respondExtension'				# tear down handler if we're disappearing...
		)


	App.ResponseController = Ember.ObjectController.extend
		mine: (->
			@get('user') is App.user.id
		).property 'user'
		isLink: (->
			return util.isLIURL @get('body')
		).property 'body'
		isMsg: (->
			return @get('body')?.length and not @get('isLink')
		).property 'body'

	App.ResponseView = Ember.View.extend
		respUserView: App.RespuserView.extend()


