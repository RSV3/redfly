# inject the store into all components and views, so can lookup there
Ember.onLoad 'Ember.Application', (Application) ->
	Application.initializer
		name: "injectStoreIntoComponentsAndViews",
		after: "store",
		initialize: (container, application) ->
			application.inject('component', 'store', 'store:main')
			application.inject('view', 'store', 'store:main')

