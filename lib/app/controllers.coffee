module.exports = (Ember, App, socket) ->

	require('./controllers/components/connection')(Ember, App, socket)
	require('./controllers/components/search')(Ember, App, socket)
	require('./controllers/components/tagger')(Ember, App, socket)
	require('./controllers/components/loader')(Ember, App, socket)

	require('./controllers/application')(Ember, App, socket)
	require('./controllers/home')(Ember, App, socket)
	require('./controllers/profile')(Ember, App, socket)
	require('./controllers/contact')(Ember, App, socket)
	require('./controllers/leaderboard')(Ember, App, socket)
	require('./controllers/contacts')(Ember, App, socket)
	require('./controllers/tags')(Ember, App, socket)
	require('./controllers/report')(Ember, App, socket)
	require('./controllers/create')(Ember, App, socket)
	require('./controllers/classify')(Ember, App, socket)
