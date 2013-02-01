module.exports = {
	positions: [
			title: 'shelf stacker'
			company:
				industry: 'retail'
				name: 'testos'
			startDate:
				month:3
				year:2012
		,
			title: 'pos pos'
			company:
				industry: 'retail'		# should pick this because it has same industry
				name: 'circlek'
			startDate:
				year:2011				# should default month to 0
		,
			title: 'irrelevant'
			company:
				industry: 'vice'		# should ignore this because it has a different industry
				name: 'dealer'
			startDate:
				month:1
				year:2010
	]
	
	pastpositions: [
			title: 'stocktaker'
			company:
				industry: 'retail'
				name: 'testos'
			startDate:
				month:0
				year:1995
			endDate:
				month:0
				year:1997
		,
			title: 'backroom'
			company:
				industry: 'retail'
				name: 'testos'
			startDate:
				month:0
				year:1995
			endDate:
				month:3
				year:1996
		,
			title: 'counter sales'
			company:
				industry: 'retail'
				name: 'competitor'
			startDate:
				month:3
				year:1991
			endDate:
				month:3
				year:1993
		,
			title: 'also irrelevant'
			company:
				industry: 'babysitting'		# should ignore this because it has a different industry
				name: 'parents'
			startDate:
				month:1
				year:2002
			startDate:
				month:1
				year:2001
	]
}
