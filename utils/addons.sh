#!/bin/bash

heroku addons:add redistogo:nano --app redfly-test
heroku addons:add zerigo_dns:basic --app redfly-test
heroku addons:add sendgrid:starter --app redfly-test
heroku addons:add bonsai:test --app redfly-test
heroku addons:add redistogo:nano --app redfly-dev
heroku addons:add zerigo_dns:basic --app redfly-dev
heroku addons:add sendgrid:starter --app redfly-dev
heroku addons:add bonsai:test --app redfly-dev
heroku addons:add redistogo:nano --app redfly-staging
heroku addons:add zerigo_dns:basic --app redfly-staging
heroku addons:add sendgrid:starter --app redfly-staging
heroku addons:add bonsai:test --app redfly-staging
heroku addons:add redistogo:nano --app redfly-prod
heroku addons:add zerigo_dns:basic --app redfly-prod
heroku addons:add sendgrid:starter --app redfly-prod
heroku addons:add bonsai:test --app redfly-prod
