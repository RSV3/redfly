_ = require 'underscore'
request = require 'request'
cheerio = require 'cheerio'
models = require './models'
linkLater = require './linklater'
util = require './util'

# for any given url
scrapeURL = (url, cb)->
	heads = {}
	# just for now, it's easiest to target the same client I can easily inspect with ...
	heads['User-Agent'] = 'Mozilla/5.0 (Windows NT 5.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/31.0.1650.16 Safari/537.36'
	request {url:url, headers:heads}, (error, response, html)->
		if error or response.statusCode isnt 200 then return cb? null
		$ = cheerio.load html
		deets =
			specialities:[]
			positions:[]
			companies:[]
		$('.profile-header').find('.image img').each (i, el)->
			deets.pictureUrl = $(this).attr 'src'
		$('.profile-header').find('span.full-name').each (i, el)->
			deets.name = $(this).text()
		$('ol.skills').find('li').each (i, el)->
			deets.specialities.push util.trim $(this).text()
		$('.position').each (i, el)->
			position = $(this).find('h3 span.title').text()
			company = $(this).find('h4 span.org').text()
			if position or company
				deets.positions.push position
				deets.companies.push company
		cb? deets



# this hook is for scraping based on the 'social' reference given by the user on the user page.
# There's no point acting on a "view?id=4031184" type address, cos they only work when you're logged in ...
scrapeContact = (user, contact, cb)->
	if not contact?.linkedin?.length then return cb? null
	if contact.linkedin.match(/^[0-9]*$/) then return cb? null		# /profile/view?id= links need valid session ...
	if contact.linkedin.match(/\//) then scrapeURL "http://www.linkedin.com/pub/#{contact.linkedin}", cb
	else scrapeURL "http://www.linkedin.com/in/#{contact.linkedin}", cb


# this module attempts to get linkedin data by scraping, where possible.

module.exports =
	contact:scrapeContact
	URL:scrapeURL
