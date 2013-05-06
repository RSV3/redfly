module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../util'

	App.AdminView = Ember.View.extend
		template: require '../../../templates/admin'
		classNames: ['admin']
		didInsertElement: ->
			@$('textarea').blur ()=>
				@get('controller').onDomain()

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
			@get('domains')?.join('\n')
		).property 'domains'
		onChk: (->
			if _.isBoolean(@get 'flushsavechk') and not _.isUndefined @get 'flushsave'
				@set 'flushsave', @get 'flushsavechk'
				@set 'userstoo', @get 'userstoochk'
				@set 'hidemails', @get 'hidemailschk'
				App.store.commit()
		).observes 'hidemailschk', 'userstoochk', 'flushsavechk'
		onDomain: (->
			if @get('domainlist')?.length
				domains = _.filter _.map(@get('domainlist').split('\n'), (d)->util.trim(d)), (d)->d.length
				console.dir domains
				@set 'domains', domains
				App.store.commit()
		)
