module.exports = (Ember, App, socket) ->
	_ = require 'underscore'

	App.ContactMixin = Ember.Mixin.create
		isKnown: (->
				u = App.user.get 'id'
				k = @get('knows')?.getEach 'id'
				@get('addedBy.id') is u or k and _.contains k, u
			).property 'addedBy', 'knows.@each.id'
		iAdded: (->
			App.user.get('id') is @get('addedBy.id')
		).property 'addedBy'
		hasIntro: (->
				@get('addedBy') and not @get('isKnown')
			).property 'addedBy', 'isKnown'
		gmailSearch: (->
				encodeURI "//gmail.com#search/to:#{@get('email')}"
			).property 'email'
		directMailto: (->
				"mailto:#{@get('canonicalName')}<#{@get('email')}>?subject=What are the haps my friend!"
			).property 'canonicalName', 'email'
		linkedinMail: (->
				'http://www.linkedin.com/requestList?displayProposal=&destID=' + @get('linkedin') + '&creationType=DC'
			).property 'linkedin'

