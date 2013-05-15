mongo = require('mongodb').MongoClient
config = require './config'

console.log config.mongo_auth

redstar_tags = {}

mongo.connect config.mongo_auth, (err, db) ->
  if err
    console.log "Connectivity error"
  else
    console.log "We are connected"

  collection = db.collection 'tags'

  collection.find({category: 'organisation'}).toArray (err, items) ->
    items.forEach (tag) ->
      if tag.body of redstar_tags
        redstar_tags[tag.body] += 1
      else
        redstar_tags[tag.body] = 1
    console.log redstar_tags
