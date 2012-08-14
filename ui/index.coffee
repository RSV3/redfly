config =
	filename: __filename
	styles: '../styles/ui'
	scripts:
		connectionAlert: require './connectionAlert'
		tagger: require './tagger'

ui = (derby, options) ->
	derby.createLibrary config, options

module.exports = ui
ui.decorate = 'derby'
