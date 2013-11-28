module.exports = (Ember, App, socket) ->
	util = require '../../util'
	_ = require 'underscore'
	moment = require 'moment'

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
				nuReq = 
					expiry: new Date @get('newdate') or moment().add(7, 'days')
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
		newDateView: App.DatePicker.extend
			placeholder: 'Expiration'
			classNames: ['span11']
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
							request.get('stateManager').send 'becameClean'
					else
						if @get 'controller.rangeStart' then return		# dont try to show new request if we're on another page
						if not @get 'controller.rangeStop' then return	# and dont bother if there's no shown
						@get('controller').reloadFirstPage()

	App.RequestController = Ember.ObjectController.extend
		count: (->
			@get('response.length') or 0
		).property 'response.@each'
		hoverable: (->
			if @get('count') then 'hoverable' else 'nothoverable'
		).property 'count'
		expires: (->
			if expireswhen = @get('expiry') then moment(expireswhen).fromNow()
		).property 'expiry'
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


	App.RequestView = Ember.View.extend
		expanded: false
		selections:[]
		newnote:''
		idsme: (->
			@get('controller.user.id') is App.user.get('id')
		).property 'controller.user'
		saveNote: (->
			not @get('newnote').length
		).property 'newnote'
		saveSuggestions: (->
			not @get('selections').length
		).property 'selections.@each'
		expand: (->
			if @get('addingcontacts') or @get('addingnote') then return
			if @get('controller.count') then it = @get('controller.content')
			else it = null
			@set 'parentView.controller.showthisreq', it
			@set 'parentView.idsme', (App.user.get('id') is it.get 'user.id')
		)
		toggle: (->
			if @get('addingcontacts') or @get('addingnote') then return
			@set 'expanded', not @get 'expanded'
		)
		closecontacts: (->
			@set 'addingcontacts', false
		)
		suggest: (->
			@set 'selections', []
			if not @get('controller.disabled') then @set 'addingcontacts', true
		)
		closenote: (->
			@set 'addingnote', false
		)
		note: (->
			@set 'newnote', ''
			@set 'addingnote', true
		)
		addNewNote: (->
			@get('controller').addNote @get 'newnote'
			@closenote()
			@set 'expanded', true
		)
		addNewContacts: (->
			@get('controller').addSuggestions @get 'selections'
			@closecontacts()
			@set 'expanded', true
		)
		newNoteView: Ember.TextArea.extend
			classNames: ['span12']
			placeholder: 'Leave a comment'
			rows: 4
		responseSearchView: App.SearchView.extend
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


	App.ResponseController = Ember.ObjectController.extend
		mine: (->
			@get('user') is App.user.id
		).property 'user'

	App.ResponseView = Ember.View.extend
		select: (->
		)

