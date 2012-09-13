module.exports = (DS, App) ->

	App.User = DS.Model.extend
		primaryKey: '_id'
		date: DS.attr 'date'
		email: DS.attr 'string'
		name: DS.attr 'string'

	App.Contact = DS.Model.extend
		primaryKey: '_id'
		date: DS.attr 'date'
		name: DS.attr 'string'
		email: DS.attr 'string'
		addedBy: DS.belongsTo 'App.User'
		dateAdded: DS.attr 'date'
		knows: DS.hasMany 'App.User'
		tags: DS.hasMany 'App.Tag'
		notes: DS.hasMany 'App.Note'

	App.Tag = DS.Model.extend
		primaryKey: '_id'
		date: DS.attr 'date'
		creator: DS.belongsTo 'App.User'
		body: DS.attr 'string'

	App.Note = DS.Model.extend
		primaryKey: '_id'
		date: DS.attr 'date'
		author: DS.belongsTo 'App.User'
		body: DS.attr 'string'

	# TODO XXX old history
	# model.set 'history.178',
	#         user: '178'
	#         contact: '178'
	#         first_email:
	#           date: +new Date
	#           subject: 'Poopty Peupty pants'
	#         count: 47
	App.Mail = DS.Model.extend
		primaryKey: '_id'
		date: DS.attr 'date'
		sender: DS.belongsTo 'App.User'
		recipient: DS.belongsTo 'App.Contact'
		subject: DS.attr 'string'
		dateSent: DS.attr 'date'


	# TODO XXX all this down is dummy and should be deleted. Also it's no longer accurate.

	# App.User = Ember.Object.create
	# 	id: 178
	# 	date: new Date
	# 	email: 'kbaranowski@redstar.com'
	# 	name: 'Krzysztof Baranowski'

	# App.Contact = Ember.Object.create
	# 	id: 178
	# 	date: new Date
	# 	name: 'John Resig'
	# 	email: 'john@name.com'
	# 	addedBy: 178
	# 	dateAdded: new Date
	# 	knows: [ 178 ]
	# 	tags: [ 'Sweet Tag Bro', 'VC' ]
	# 	notes: [
	# 		date: new Date
	# 		author: 178
	# 		text: 'Lorem ipsum dolor ist asdf asdfadf dasf adsf adsf adsf asdfads fads fads'
	# 	]

	# App.Mail = Ember.Object.create
	# 	id: 178
	# 	date: new Date
	# 	sender: 178
	# 	recipient: 178
	# 	subject: 'Poopty Peupty pants'
	# 	dateSent: new Date
