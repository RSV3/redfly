mongo = require('mongodb').MongoClient
config = require './config'

console.log config.mongo_auth

mongo.connect config.mongo_auth, (err, db) ->
  redstar_tags = {}
  if err
    console.log "Connectivity error"
  else
    console.log "We are connected"

  collection = db.collection 'tags'

  redstar_tags = collection.find({category: 'organisation'}).toArray (err, items) ->
    items.forEach (tag) ->
      if tag.body of redstar_tags
        redstar_tags[tag.body] += 1
      else
        redstar_tags[tag.body] = 1
    redstar_tags

  console.log redstar_tags
