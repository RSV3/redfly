chai = require 'chai'

chai.Should()

linker = require '../linker.coffee'
data = require './data.coffee'

describe 'test comparison', ->
	it 'should have length', ->
		data.length.should.not.equal 0

describe 'test matchC', ->
	it 'should not crash', ->
		for contact in data
			linker.matchContact {user_id:0}, contact[0], contact[1], contact[0]+contact[1], (o) ->
				console.dir o

describe 'test experience calculation', ->
	it 'should calculate accurately', ->
		contact = 
			position: 'shelf stacker'
			company: 'testos'
		details = require './fixtures.coffee'
		linker.calculateExperience(contact, details).should.equal 6
