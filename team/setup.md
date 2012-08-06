- Install Node.js 0.8.5

- Clone project from github.
	git clone git@github.com:RSV3/redfly.git

- Add the git remotes for respective environments.
	heroku git:remote -a redfly-dev -r heroku-dev
	heroku git:remote -a redfly-test -r heroku-test
	heroku git:remote -a redfly-staging -r heroku-staging
	heroku git:remote -a redfly-prod -r heroku-prod

- Set the test remote as default for heroku commands.
	git config heroku.remote test

- Make git automatically push changes in local branches to remote repositories they track.
	git config push.default upstream

- Get all remote branches locally (test, staging, prod). Make sure they're all tracking the corresponding remote branches.





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


heroku addons:add redistogo:nano --app redfly-dev
heroku addons:add zerigo_dns:basic --app redfly-dev
heroku addons:add sendgrid:starter --app redfly-dev
heroku addons:add bonsai:test --app redfly-dev
heroku addons:add mongolab:starter --app redfly-dev
heroku addons:add memcachier:dev --app redfly-dev
heroku addons:add redistogo:nano --app redfly-test
heroku addons:add zerigo_dns:basic --app redfly-test
heroku addons:add sendgrid:starter --app redfly-test
heroku addons:add bonsai:test --app redfly-test
heroku addons:add neo4j:test --app redfly-test
heroku addons:add mongolab:starter --app redfly-test
heroku addons:add memcachier:dev --app redfly-test
heroku addons:add redistogo:nano --app redfly-staging
heroku addons:add zerigo_dns:basic --app redfly-staging
heroku addons:add sendgrid:starter --app redfly-staging
heroku addons:add bonsai:test --app redfly-staging
heroku addons:add mongolab:starter --app redfly-staging
heroku addons:add memcachier:dev --app redfly-staging
heroku addons:add redistogo:nano --app redfly-prod
heroku addons:add zerigo_dns:basic --app redfly-prod
heroku addons:add sendgrid:starter --app redfly-prod
heroku addons:add bonsai:test --app redfly-prod
heroku addons:add mongolab:starter --app redfly-prod
heroku addons:add memcachier:dev --app redfly-prod

