module.exports = (Ember, App, socket) ->

	require('./controllers/components/connection.coffee') Ember, App, socket
	require('./controllers/components/edit-picture.coffee') Ember, App, socket
	require('./controllers/components/hoveruser.coffee') Ember, App, socket
	require('./controllers/components/intro.coffee') Ember, App, socket
	require('./controllers/components/linker.coffee') Ember, App, socket
	require('./controllers/components/loader.coffee') Ember, App, socket
	require('./controllers/components/newtag.coffee') Ember, App, socket
	require('./controllers/components/note.coffee') Ember, App, socket
	require('./controllers/components/search.coffee') Ember, App, socket
	require('./controllers/components/social.coffee') Ember, App, socket
	require('./controllers/components/tag.coffee') Ember, App, socket
	require('./controllers/components/tagadmin.coffee') Ember, App, socket
	require('./controllers/components/tagger.coffee') Ember, App, socket
	require('./controllers/components/fulltagger.coffee') Ember, App, socket

	require('./controllers/sidebars/pastreqs.coffee') Ember, App, socket
	require('./controllers/sidebars/leaders.coffee') Ember, App, socket
	require('./controllers/sidebars/filter.coffee') Ember, App, socket
	require('./controllers/sidebars/feed.coffee') Ember, App, socket

	require('./controllers/admin.coffee') Ember, App, socket
	require('./controllers/application.coffee') Ember, App, socket
	require('./controllers/classify.coffee') Ember, App, socket
	require('./controllers/companies.coffee') Ember, App, socket
	require('./controllers/contact.coffee') Ember, App, socket
	require('./controllers/contacts.coffee') Ember, App, socket
	require('./controllers/create.coffee') Ember, App, socket
	require('./controllers/dashboard.coffee') Ember, App, socket
	require('./controllers/home.coffee') Ember, App, socket
	require('./controllers/import.coffee') Ember, App, socket
	require('./controllers/leaderboard.coffee') Ember, App, socket
	require('./controllers/profile.coffee') Ember, App, socket
	require('./controllers/report.coffee') Ember, App, socket
	require('./controllers/results.coffee') Ember, App, socket
	require('./controllers/responses.coffee') Ember, App, socket
	require('./controllers/requests.coffee') Ember, App, socket
	require('./controllers/tags.coffee') Ember, App, socket

