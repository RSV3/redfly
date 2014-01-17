module.exports = (Ember, App, socket) ->
	util = require '../util'
	_ = require 'underscore'
	moment = require 'moment'

	###
	App.DatePicker = Ember.View.extend
		classNames: ['ember-text-field']
		tagName: "input"
		attributeBindings: ['data','value','format','readonly','type','size']
		size:"16"
		type: "text"
		format:'mm/dd/yyyy'
		data:null
		clear: (->
			if not @get 'parentView.controller.newdate'
				@$().datepicker('setDate', null)
		).observes 'parentView.controller.newdate'
		didInsertElement: (->
			parent = @get 'parentView.controller'
			@$().attr('placeholder', 'set an expiry date').datepicker
				format: @get 'format'
				minDate: 0
				defaultDate: 7
				maxDate: 99
				onClose: (thdate)->
					parent.set 'newdate', thdate
		)
		willDestroyElement: (->
			@$().datepicker('destroy')
		)
	###

	App.RequestsController = Ember.ObjectController.extend
		hasPrev: false
		hasNext: false
		rangeStart: 0
		rangeStop: (->
			@get('rangeStart') + @get('reqs.length')
		).property 'rangeStart', 'reqs'
		hasPrev: (->
			@get('rangeStart')
		).property 'rangeStart'
		pageSize:0
		reqs:null
		newreq:null
		newdate:null
		urgent: false
		prevPage: (->
			socket.emit 'requests', {skip:@get('rangeStart')-@get('pageSize')}, (reqs, theresmore)=>
				if reqs
					@set 'reqs', App.store.findMany(App.Request, reqs)
					@set 'hasNext', true
					@set 'rangeStart', @get('rangeStart') - @get('pageSize')
		)
		nextPage: (->
			socket.emit 'requests', {skip:@get('rangeStart')+@get('pageSize')}, (reqs, theresmore)=>
				if reqs
					@set 'reqs', App.store.findMany(App.Request, reqs)
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
				nuReqRec = App.Request.createRecord nuReq
				App.store.commit()
				@set 'newreq', null
				@set 'newdate', null
				@set 'urgent', null
				nuReqRec.addObserver 'id', =>
					@reloadFirstPage()
		)
		reloadFirstPage: (->
			socket.emit 'requests', (reqs, theresmore)=>
				@set 'reqs', App.store.findMany App.Request, reqs
				@set 'hasNext', theresmore
		)
		disableAdd: (->
			not @get('newreq')?.length
		).property 'newreq'

	App.RequestsView = Ember.View.extend
		template: require '../../../templates/requests'
		classNames: ['requests']
		toggleUrgency: (->
			@set 'controller.urgent', not @get 'controller.urgent'
		)
		newReqView: Ember.TextArea.extend
			classNames: ['span12']
			placeholder: 'New request'
			rows: 5
			tabindex: 1
		###
		newDateView: App.DatePicker.extend
			placeholder: 'Expiration'
			classNames: ['span11']
		###
		didInsertElement: ->
			socket.on 'feed', (data) =>
				if not data or data.type isnt 'Request' or not data.id then return
				Ember.run.next this, ->
					if data.response?.length	# update
						isLoaded = App.store.recordIsLoaded App.Request, data.id
						if isLoaded
							request = App.Request.find data.id
							responses = request.get 'response'
							new_resp = _.without data.response, responses.getEach('id')
							_.each new_resp, (r)-> responses.addObject App.Response.find r
							Ember.run.next this, ->
								request.get('stateManager').send 'becameClean'
					else
						if @get 'controller.rangeStart' then return		# dont try to show new request if we're on another page
						if not @get 'controller.rangeStop' then return	# and dont bother if there's no shown
						@get('controller').reloadFirstPage()

	App.RequestController = Ember.ObjectController.extend
		hovering: null
		count: (->
			@get('response.length') or 0
		).property 'response.@each'
		hoverable: (->
			if @get('count') then 'hoverable' else 'nothoverable'
		).property 'count'
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
			newnote = App.Response.createRecord
				user: App.user
				body: note
			App.store.commit()
			self = @
			newnote.addObserver 'id', ->
				self.get('response').pushObject newnote
				App.store.commit()
		addSuggestions: (suggestions)->
			suggestion = App.Response.createRecord
				user: App.user
				contact: []
			_.each suggestions, (r)-> suggestion.get('contact').pushObject r
			App.store.commit()
			self = @
			suggestion.addObserver 'id', ->
				self.get('response').pushObject suggestion
				App.store.commit()

	App.RequserView = App.HoveruserView.extend
		template: require '../../../templates/components/requser'

	App.RespuserView = App.HoveruserView.extend
		template: require '../../../templates/components/respuser'

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
					if ev.url then @set 'newnote', ev.url
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
			if @get('controller.count') then it = @get('controller.content')
			else it = null
			@set 'parentView.idsme', App.user.get('id') is it?.get('user.id')
			@set 'parentView.controller.showthisreq', it
			Ember.run.next this, ->
				@get('parentView').$('.thisReq').removeClass('myLightSpeedOut').addClass('animated myLightSpeedIn')
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
			App.store.commit()
		)
		addResponse: (->
			if @get('selectedSearchContacts') then @get('controller').addSuggestions @get 'selections'
			else @get('controller').addNote @get 'newnote'
			@cancel()
			@set 'expanded', true
		)
		reqUserView: App.RequserView.extend()
		leaveLinkView: Ember.TextArea.extend
			classNames: ['span12']
			placeholder: 'Paste Linkedin url'
			rows: 1
		newNoteView: Ember.TextArea.extend
			classNames: ['span12']
			placeholder: 'Leave a message'
			rows: 1
		responseSearchView: App.SearchView.extend
			classNames: ['span12']
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
				@get('parentView.selections').addObject App.Contact.find context.id
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


