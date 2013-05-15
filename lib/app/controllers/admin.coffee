module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../util'

	App.AdminView = Ember.View.extend
		template: require '../../../templates/admin'
		classNames: ['admin']
		didInsertElement: ->
			@$('textarea').blur ()=>
				@get('controller')._onTextArea()

	App.AdminController = Ember.ObjectController.extend
		flushsavechk: (->
			@get 'flushsave'
		).property 'flushsave'
		hidemailschk: (->
			@get 'hidemails'
		).property 'hidemails'
		userstoochk: (->
			@get 'userstoo'
		).property 'userstoo'
		domainlist: (->
			@get('domains')?.join '\n'
		).property 'domains'
		domainblacklist: (->
			@get('blacklistdomains')?.join '\n'
		).property 'blacklistdomains'
		nameblacklist: (->
			@get('blacklistnames')?.join '\n'
		).property 'blacklistnames'
		emailblacklist: (->
			@get('blacklistemails')?.join '\n'
		).property 'blacklistemails'
		onChk: (->
			if _.isBoolean(@get 'flushsavechk') and not _.isUndefined @get 'flushsave'
				@set 'flushsave', @get 'flushsavechk'
				@set 'userstoo', @get 'userstoochk'
				@set 'hidemails', @get 'hidemailschk'
				App.store.commit()
		).observes 'hidemailschk', 'userstoochk', 'flushsavechk'
		_onTextArea: (->
			if @get('domainlist')?.length
				@set 'domains',  _.filter _.map(@get('domainlist').split('\n'), (d)->util.trim(d)), (d)->d.length
				@set 'blacklistdomains', _.filter _.map(@get('domainblacklist').split('\n'), (d)->util.trim(d)), (d)->d.length
				
				@set 'blacklistemails', _.filter _.map(@get('emailblacklist').split('\n'), (d)->util.trim(d)), (d)->d.length
				@set 'blacklistnames', _.filter _.map(@get('nameblacklist').split('\n'), (d)->util.trim(d)), (d)->d.length
				App.store.commit()
		)
