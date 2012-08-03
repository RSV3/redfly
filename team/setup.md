- Install Node.js 0.8.5

- Clone project from github.
	git clone git@github.com:RSV3/redfly.git

- Add the git remotes for respective environments.
	heroku git:remote -a redfly-dev -r dev
	heroku git:remote -a redfly-test -r test
	heroku git:remote -a redfly-staging -r staging
	heroku git:remote -a redfly-prod -r prod

- Set the test remote as default for heroku commands.
	git config heroku.remote test

- Make git automatically push changes in local branches to remote repositories they track.
	git config push.default upstream

- Get all remote branches (test, staging, prod)





----- One-time setup -------

- Add config variable for each environment to heroku
	heroku config:add APP_ENV=development --remote dev
	heroku config:add APP_ENV=test --remote test
	heroku config:add APP_ENV=staging --remote staging
	heroku config:add APP_ENV=prod --remote prod


- Add the branches for each environment
	git branch test
	git branch staging
	git branch prod
	git push -u origin test
	git push -u origin staging
	git push -u origin prod



Heroku Add-Ons added
====================

* neo4j
* mongolab
* memcache
* mailgun
