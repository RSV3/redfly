modelsUtil = require 'phrenetic/lib/server/models'
services = require 'phrenetic/lib/server/services'
schemas = require '../schemas'
_ = require 'underscore'

frames = modelsUtil.frame schemas

module.exports = _.extend modelsUtil.compile(frames),
	ObjectId: (n)->
		services.getDb().Types.ObjectId(n)
	tmStmp: (id)->
		parseInt id.toString().slice(0,8), 16

