module.exports = (Ember, App, socket) ->
	_ = require 'underscore'

	App.ContactMixin = Ember.Mixin.create
		isKnown: (->
				u = App.user.get 'id'
				k = @get('knows')?.getEach 'id'
				@get('addedBy') is u or k and _.contains k, u
			).property 'addedBy', 'knows.@each.id'
		hasIntro: (->
				@get('addedBy') and not @get('isKnown')
			).property 'addedBy', 'isKnown'
		gmailSearch: (->
				encodeURI "//gmail.com#search/to:#{@get('email')}"
			).property 'email'
		directMailto: (->
				"mailto:#{@get('canonicalName')}<#{@get('email')}>?subject=What are the haps my friend!"
			).property 'canonicalName', 'email'
		introMailto: (->
				CR = '%0D%0A'		# carriage return / line feed
				baseUrl = "http://#{window.location.hostname}"
				port = if window.location.port then ":#{window.location.port}" else ""
				url = "#{baseUrl}#{port}/contact/#{@get 'id'}"
				"mailto:#{@get('addedBy.canonicalName')} <#{@get('addedBy.email')}>" +
					"?subject=You know #{@get('nickname')}, right?" +
					"&body=Hey #{@get('addedBy.nickname')}, would you kindly give me an intro to #{@get('canonicalName')}?#{CR}This fella right here: #{CR}#{CR}#{encodeURI(url)}#{CR}#{CR}Your servant,#{CR}#{App.user.get('nickname')}"
			).property 'nickname', 'canonicalName', 'addedBy.canonicalName', 'addedBy.email', 'addedBy.nickname', 'App.user.nickname'
		linkedinMail: (->
				'http://www.linkedin.com/requestList?displayProposal=&destID=' + @get('linkedin') + '&creationType=DC'
			).property 'linkedin'

