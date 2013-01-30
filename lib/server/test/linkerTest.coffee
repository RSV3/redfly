chai = require 'chai'

chai.Should()

linker = require '../linker.coffee'
csv = require './test.csv'

describe 'test comparison', ->
	it 'should have length', ->
		csv.length.should.not.equal 0

describe 'test matchC', ->
	it 'should not crash', ->
		for contact in csv
			linker.matchContact {user_id:0}, contact[0], contact[1], contact[0]+contact[1], (o) ->
				console.dir o

describe 'test experience calculation', ->
	it 'should calculate accurately', ->
		contact = 
			position: 'shelf stacker'
			company: 'testos'
		details = require './fakedeets.coffee'
		linker.calculateXperience(contact, details).should.equal 6

