module.exports = (Ember, App, socket) ->

	App.ResultsController = Ember.ArrayController.extend App.Pagination,
		itemController: 'result'
		itemsPerPage: 3
		content: []
		yearsToSelect: []
		years: 0
		unfilteredContent: null
		originalContent: ->
			if not @unfilteredContent
				fc = @get('fullContent')
				if !fc.get('content.length') then return fc
				@unfilteredContent = fc.get('content').slice(0)
			@unfilteredContent
		maxyrs: ->
			my = 0
			fc = @get('fullContent').slice(0)
			for i in fc
				if i.get('yearsExperience') > my
					my = i.get('yearsExperience')
			my
		selectYears: (->
				console.log @get('years')
				if (a= @.originalContent())
					newa = []
					if (@years)
						for c in a
							if c.get('yearsExperience') >= @years
								newa.push c
						@set('fullContent.content', newa)
					else
						@set('fullContent.content', a)
					@set('rangeStart', 0)
				). observes 'years'

		mypageChanged: (->
				if @get('total')
					@set('yearsToSelect', [])
					max = @maxyrs()
					if max
						for i in [max..1]
							@get('yearsToSelect').push Ember.Object.create({label: 'at least '+i+' years', years:i})
			).observes 'total'

	App.ResultsView = Ember.View.extend
		template: require '../../../views/templates/results'

	App.ResultController = Ember.Controller.extend

	App.ResultView = Ember.View.extend App.SomeContactMethods,
		template: require '../../../views/templates/result'
		introView: App.IntroView
		socialView: App.SocialView
		classNames: ['contact']
