module.exports = (Ember, App) ->

	App.PluginController = Ember.Controller.extend()

	App.PluginView = Ember.View.extend
		template: require '../../../templates/plugin.jade'
		didInsertElement: ->
			$('#installationlink').click ->
				chrome.webstore.install App.admin.get('plugin'), (o)->
					console.log 'returned from install ...'
					App.admin.set 'extensionOn', true
					console.dir o
					false
				, (o)->
					console.log 'failed from install ...'
					console.dir o
					false
				false
