module.exports = (Ember, App, socket) ->

	App.ContactMixin = Ember.Mixin.create
		isKnown: (->
				@get('controller.knows')?.find (user) ->
					user.get('id') is App.user.get('id')	# TO-DO maybe this can be just "user is App.user.get('content')"
			).property 'controller.knows.@each.id'
		gmailSearch: (->
				encodeURI '//gmail.com#search/to:' + @get('controller.email')
			).property 'controller.email'
		directMailto: (->
				'mailto:'+ @get('controller.canonicalName') + ' <' + @get('controller.email') + '>' + '?subject=What are the haps my friend!'
			).property 'controller.canonicalName', 'controller.email'
		introMailto: (->
				carriage = '%0D%0A'
				baseUrl = 'http://' + window.location.hostname + (window.location.port and ":" + window.location.port)
				url = baseUrl + '/contact/' + @get 'controller.id'
				'mailto:' + @get('controller.addedBy.canonicalName') + ' <' + @get('controller.addedBy.email') + '>' +
					'?subject=You know ' + @get('controller.nickname') + ', right?' +
					'&body=Hey ' + @get('controller.addedBy.nickname') + ', would you kindly give me an intro to ' + @get('controller.canonicalName') + '? ' +
					'This fella right here:' + carriage + carriage + encodeURI(url) +
					carriage + carriage + 'Your servant,' + carriage + App.user.get('nickname')
			).property 'controller.nickname', 'controller.canonicalName', 'controller.addedBy.canonicalName', 'controller.addedBy.email', 'controller.addedBy.nickname', 'App.user.nickname'
		linkedinMail: (->
				'http://www.linkedin.com/requestList?displayProposal=&destID=' + @get('controller.linkedin') + '&creationType=DC'
			).property 'controller.linkedin'
