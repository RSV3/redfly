window.jQuery = window.$ = require('jquery')	# avoid duplicating jquery by using node_module
require './jquery-ui.js'	# For pnotify effects.

require './bootstrap.js'
require './typeahead.bundle.js'
require './jquery.pnotify.js'

window.Handlebars = require 'handlebars'
require './ember.js'
require './ember-data.js'
