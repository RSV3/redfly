- Install Node.js 0.8.5

- Clone project from github.
	git clone git@github.com:RSV3/redfly.git

- Add the git remotes for respective environments.
	heroku git:remote -a redfly-development
	heroku git:remote -a redfly-test
	heroku git:remote -a redfly-staging
	heroku git:remote -a redfly-production

- Set the test remote as default for heroku commands.
	git config heroku.remote test

- Make git automatically push changes in local branches to remote repositories they track.
	git config push.default upstream

- Add the branches for each environment
	git checkout -b test --track test/master
	git checkout -b staging --track staging/master
	git checkout -b production --track production/master



Heroku Add-Ons added
====================

* neo4j
* mongolab
* memcache
* mailgun
