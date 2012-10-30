- Install Node.js 0.8.7

- Clone project from github.
	git clone git@github.com:RSV3/redfly.git

- Add the git remotes for respective environments.
	heroku git:remote -a redfly-dev -r heroku-dev
	heroku git:remote -a redfly-test -r heroku-test
	heroku git:remote -a redfly-staging -r heroku-staging
	heroku git:remote -a redfly-prod -r heroku-prod

- Set the test remote as default for heroku commands.
	git config heroku.remote heroku-test

- Make git automatically push changes in local branches to remote repositories they track.
	git config push.default upstream

- Get all remote branches locally (test, staging, prod). Make sure they're all tracking the corresponding remote branches.





Util
========================================

development commands:
mongo ds037067-a.mongolab.com:37067/heroku_app6379653 -u heroku_app6379653 -p p1kafm34rqlg2a233c700j0bcj
redis-cli -h koi.redistogo.com -p 9609 -a d8fafc860dfba6c9d50b6dbabc90653b

test commands:
mongo ds037097.mongolab.com:37097/heroku_app6375910 -u heroku_app6375910 -p osf31ssqike03ju6i6852jd0v2

dumping prod db to dev:
mongodump --host ds039147.mongolab.com:39147 --username heroku_app8065862 --password 6cqi48lldblomdf4uebuhplblj --db heroku_app8065862 --out redfly_dump
mongorestore --host ds037067-a.mongolab.com:37067 --username heroku_app6379653 --password p1kafm34rqlg2a233c700j0bcj --db heroku_app6379653 redfly_dump/heroku_app8065862

get all tags:
require('./models').Tag.find body: /whatever/, (err, tags) ->
	throw err if err
	console.log tags





One-time setup
==============

- Add config variable for each environment to heroku
	heroku config:add APP_ENV=development --remote heroku-dev
	heroku config:add APP_ENV=test --remote heroku-test
	heroku config:add APP_ENV=staging --remote heroku-staging
	heroku config:add APP_ENV=prod --remote heroku-prod


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

