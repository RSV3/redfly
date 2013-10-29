module.exports = (Ember, App, socket) ->
	util = require '../../util'
	moment = require 'moment'

	App.DatePicker = Ember.View.extend
		classNames: ['ember-text-field']
		tagName: "input"
		attributeBindings: ['data','value','format','readonly','type','size']
		size:"16"
		type: "text"
		format:'mm/dd/yyyy'
		value: (->
			if not (date = @get 'data') then return ""
			date.format @get 'format'
		).property('data')
		data:null
		didInsertElement: (->
			self = @
			onChangeDate = (ev)->
				self.set 'data', ev.date
			options =
				format: @get 'format'
				minDate: 0
				defaultDate: 7
				maxDate: 99
			@$().attr('placeholder', 'set an expiry date').datepicker(options).on 'changeDate', onChangeDate
		)

	App.RequestsController = Ember.ObjectController.extend
		reqs:null
		newreq:null
		newdate:null
		urgent: false
		add: (->
			if note = util.trim @get('newreq')
				App.Request.createRecord
					created: new Date
					expiry: new Date @get('newdate') or moment().add(7, 'days')
					user: App.user
					urgent: @get 'urgent'
					text: note
					suggestions: []
				App.store.commit()
				@set 'newreq', null
				@set 'newdate', null
				@set 'urgent', null
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


	App.RequestController = Ember.ObjectController.extend
		count: (->
			@get('suggestions.length') or 0
		).property 'suggestions'
		expires: (->
			if expireswhen = @get('expiry') then moment(expireswhen).fromNow()
		).property 'expiry'
		disabled: (->
			if @get('user')?.get('id') is App.user.id then "disabled"
		).property 'user'

	App.RequestView = Ember.View.extend
		expanded: false
		toggle: (->
			@set 'expanded', not @get 'expanded'
		)

