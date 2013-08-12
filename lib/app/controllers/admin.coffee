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
		anyeditchk: (->
			@get('anyedit') isnt false		# default (init) to true
		).property 'anyedit'
		hidemailschk: (->
			@get('hidemails') isnt false		# default (init) to true
		).property 'hidemails'
		userstoochk: (->
			@get('userstoo') is true			# default (init) to false
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
			@set 'flushsave', @get 'flushsavechk'
			@set 'userstoo', @get 'userstoochk'
			@set 'hidemails', @get 'hidemailschk'
			@set 'anyedit', @get 'anyeditchk'
			App.store.commit()
		).observes 'hidemailschk', 'userstoochk', 'flushsavechk', 'anyeditchk'
		_onTextArea: (->
			if @get('domainlist')?.length
				regexp = /(?:,|\n)+/
				@set 'domains',  _.filter _.map(@get('domainlist').split(regexp), (d)->util.trim(d)), (d)->d.length
				@set 'blacklistdomains', _.filter _.map(@get('domainblacklist').split(regexp), (d)->util.trim(d)), (d)->d.length
				
				@set 'blacklistemails', _.filter _.map(@get('emailblacklist').split(regexp), (d)->util.trim(d)), (d)->d.length
				@set 'blacklistnames', _.filter _.map(@get('nameblacklist').split(regexp), (d)->util.trim(d)), (d)->d.length
				App.store.commit()
		)
