_ = require 'underscore'
derby = require 'derby'

{get, view, ready} = derby.createApp module

derby.use(require '../../ui')

require './home'
require './contact'
require './search'
require './tags'
require './report'
