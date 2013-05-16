projectRoot = require('path').dirname("/Users/kwan/workspace/redfly/analytics/")

require('../node_modules/phrenetic/lib/server/config')(projectRoot)
service = require('../node_modules/phrenetic/lib/server/services')

models = require '../lib/server/models'

redstar_tags = {}

Tag = models.Tag

tag_stream = Tag.find({category: 'organisation'}).stream()

tag_stream.on 'data', (tag) ->
  if tag.body of redstar_tags
    redstar_tags[tag.body] += 1
  else
    redstar_tags[tag.body] = 1

tag_stream.on 'error', (err) ->
  console.log "DB error while reading"

tag_stream.on 'close', () ->
  console.log redstar_tags
  service.getDb().disconnect()
