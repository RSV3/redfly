module.exports = (Ember, App, socket) ->

	# This is stupid. Just instantiate directly, this wrapper adds no value.
	App.filter = (type, sort, query, filter) ->
		records = type.filter query, filter
		sort.asc ?= true
		options =
			content: records
			sortProperties: [sort.field]
			sortAscending: sort.asc
		Ember.ArrayProxy.create Ember.SortableMixin, options
	

	require('./controllers/components/connection')(Ember, App, socket)
	require('./controllers/components/search')(Ember, App, socket)
	require('./controllers/components/tag')(Ember, App, socket)
	require('./controllers/components/tagger')(Ember, App, socket)
	require('./controllers/components/loader')(Ember, App, socket)
	require('./controllers/components/linker')(Ember, App, socket)
	require('./controllers/components/edit-picture')(Ember, App, socket)
	require('./controllers/components/intro')(Ember, App, socket)
	require('./controllers/components/social')(Ember, App, socket)
	require('./controllers/components/note')(Ember, App, socket)
	require('./controllers/components/somecontact')(Ember, App, socket)

	require('./controllers/sidebars/search-filter')(Ember, App, socket)
	require('./controllers/sidebars/feed')(Ember, App, socket)
	require('./controllers/application')(Ember, App, socket)
	require('./controllers/home')(Ember, App, socket)
	require('./controllers/profile')(Ember, App, socket)
	require('./controllers/results')(Ember, App, socket)
	require('./controllers/contact')(Ember, App, socket)
	require('./controllers/leaderboard')(Ember, App, socket)
	require('./controllers/contacts')(Ember, App, socket)
	require('./controllers/tags')(Ember, App, socket)
	require('./controllers/report')(Ember, App, socket)
	require('./controllers/create')(Ember, App, socket)
	require('./controllers/classify')(Ember, App, socket)
	require('./controllers/import')(Ember, App, socket)
