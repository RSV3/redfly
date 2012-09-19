module.exports = (DS, App) ->

	App.User = DS.Model.extend
		primaryKey: '_id'
		date: DS.attr 'date'
		email: DS.attr 'string'
		name: DS.attr 'string'
		classifyIndex: DS.attr 'number'
		classify: DS.hasMany 'App.Contact'

	App.Contact = DS.Model.extend
		primaryKey: '_id'
		date: DS.attr 'date'
		name: DS.attr 'string'
		email: DS.attr 'string'
		addedBy: DS.belongsTo 'App.User'
		dateAdded: DS.attr 'date'
		knows: DS.hasMany 'App.User'
		# TODO consider sideloading these?
		# tags: DS.hasMany 'App.Tag'
		# notes: DS.hasMany 'App.Note'

	App.Tag = DS.Model.extend
		primaryKey: '_id'
		date: DS.attr 'date'
		creator: DS.belongsTo 'App.User'
		contact: DS.belongsTo 'App.Contact'
		body: DS.attr 'string'

	App.Note = DS.Model.extend
		primaryKey: '_id'
		date: DS.attr 'date'
		author: DS.belongsTo 'App.User'
		contact: DS.belongsTo 'App.Contact'
		body: DS.attr 'string'

	App.Mail = DS.Model.extend
		primaryKey: '_id'
		date: DS.attr 'date'
		sender: DS.belongsTo 'App.User'
		recipient: DS.belongsTo 'App.Contact'
		subject: DS.attr 'string'
		dateSent: DS.attr 'date'
