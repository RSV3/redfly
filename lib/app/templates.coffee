module.exports = (Ember) ->
	templates = Ember.TEMPLATES

	templates.application = require '../../templates/application.jade'
	templates.app1 = require '../../templates/app1.jade'
	templates.app2 = require '../../templates/app2.jade'

	templates._contact = require '../../templates/partials/_contact.jade'
	templates._response = require '../../templates/partials/_response.jade'
	templates._results = require '../../templates/partials/_results.jade'
	templates._sorting = require '../../templates/partials/_sorting.jade'
	templates._paging = require '../../templates/partials/_paging.jade'
	templates._linkedinresults = require '../../templates/partials/_linkedinresults.jade'
	templates._commentresults = require '../../templates/partials/_commentresults.jade'
	templates._hoveruser = require '../../templates/partials/_hoveruser.jade'

	templates.index = require '../../templates/home.jade'
	templates.classify = require '../../templates/classify.jade'
	templates.contact = require '../../templates/contact.jade'
	templates.contacts = require '../../templates/contacts.jade'
	templates.create = require '../../templates/create.jade'
	templates.import = require '../../templates/import.jade'
	templates.leaderboard = require '../../templates/leaderboard.jade'
	templates.profile = require '../../templates/profile.jade'
	templates.report = require '../../templates/report.jade'
	templates.tags = require '../../templates/tags.jade'
	templates.responses = require '../../templates/responses.jade'
	templates.results = require '../../templates/results.jade'
	templates.dashboard = require '../../templates/dashboard.jade'
	templates.admin = require '../../templates/admin.jade'
	templates.companies = require '../../templates/companies.jade'
	templates.requests = require '../../templates/requests.jade'

	templates.pastreqs = require '../../templates/sidebars/pastreqs.jade'
	templates.leaders = require '../../templates/sidebars/leaders.jade'
	templates.filter = require '../../templates/sidebars/filter.jade'
	templates.feed = require '../../templates/sidebars/feed.jade'

