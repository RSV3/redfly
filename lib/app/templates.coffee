module.exports = (Ember) ->
	templates = Ember.TEMPLATES

	templates.application = require '../../templates/application'

	templates.index = require '../../templates/home'
	templates.classify = require '../../templates/classify'
	templates._contact = require '../../templates/_contact'
	templates.contact = require '../../templates/contact'
	templates.contacts = require '../../templates/contacts'
	templates.create = require '../../templates/create'
	templates.import = require '../../templates/import'
	templates.leaderboard = require '../../templates/leaderboard'
	templates.profile = require '../../templates/profile'
	templates.report = require '../../templates/report'
	templates.tags = require '../../templates/tags'
	templates.results = require '../../templates/results'
	templates.dashboard = require '../../templates/dashboard'
	templates.admin = require '../../templates/admin'
	templates.companies = require '../../templates/companies'

	templates.filter = require '../../templates/sidebars/filter'
	templates.feed = require '../../templates/sidebars/feed'

