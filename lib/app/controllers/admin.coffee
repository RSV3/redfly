module.exports = (Ember, App, socket) ->
	_ = require 'underscore'
	util = require '../util.coffee'

	App.AdminView = Ember.View.extend
		template: require '../../../templates/admin.jade'
		classNames: ['admin']
		didInsertElement: ->
			@$('textarea').blur ()=>
				@get('controller')._onTextArea()
		editme: (ev)->
			$it = @$("li.editable.#{ev}")
			if not $it.hasClass('alreadyhere')
				@$('li.alreadyhere').removeClass 'alreadyhere'
				$it.addClass 'alreadyhere'
				return false
			$it.replaceWith '<input class="changeCats">'
			oldText = $it.text().trim()
			handleUpkey = (event)=>
				if event.which is 13	# Enter.
					$(event.currentTarget).blur()
					return false
				else if event.which is 27	# Escape.
					$(event.currentTarget).val(oldText).blur()
				else return true
			@$('input.changeCats').val(oldText).focus().keyup(handleUpkey).blur (ev)->
				$newInput = $(this)
				newText = $newInput.val().trim()
				if not newText.length then return $newInput.replaceWith $it
				renameTagCategory = ()=>
					App.admin.set $it.find('a').attr('href'), newText		# fugly~!
					App.admin.set 'orgtagcats', "#{App.admin.get 'orgtagcat1'}, #{App.admin.get 'orgtagcat2'}, #{App.admin.get 'orgtagcat3'}"
					$newInput.replaceWith $it
					$it.val newText
					App.store.commit()
				unless newText is oldText
					bootbox.dialog "Change tag category name from \"<b>#{oldText}</b>\" to \"<b>#{$newInput.val()}</b>\"", [
						"label" : "Rename old tags",
						"class" : "btn-success",
						"callback": ()=>
							socket.emit 'renameTags', {old:oldText, new:newText}, ()->
								renameTagCategory $it, $newInput
					,
						"label" : "Ignore old tags",
						"class" : "btn-warning",
						"callback": ()=>
							renameTagCategory $it, $newInput
					,
						"label" : "Cancel",
						"class" : "btn-danger",
						"callback": ()=>
							$newInput.replaceWith $it
					]
				else $newInput.replaceWith $it


	App.AdminController = Ember.ObjectController.extend
		totalThisMonth: 0
		autoThisMonth: 0
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
		authdomainlist: (->
			@get('authdomains')?.join '\n'
		).property 'domains'
		domainblacklist: (->
			@get('blacklistdomains')?.join '\n'
		).property 'blacklistdomains'
		nameblacklist: (->
			@get('blacklistnames')?.join '\n'
		).property 'blacklistnames'
		emailwhitelist: (->
			@get('whitelistemails')?.join '\n'
		).property 'whitelistemails'
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
				@set 'authdomains',  _.filter _.map(@get('authdomainlist').split(regexp), (d)->util.trim(d)), (d)->d.length
				@set 'blacklistdomains', _.filter _.map(@get('domainblacklist').split(regexp), (d)->util.trim(d)), (d)->d.length
				
				@set 'blacklistemails', _.filter _.map(@get('emailblacklist').split(regexp), (d)->util.trim(d)), (d)->d.length
				@set 'whitelistemails', _.filter _.map(@get('emailwhitelist').split(regexp), (d)->util.trim(d)), (d)->d.length
				@set 'blacklistnames', _.filter _.map(@get('nameblacklist').split(regexp), (d)->util.trim(d)), (d)->d.length
				App.store.commit()
		)

