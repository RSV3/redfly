#!/bin/sh

# run from the master branch after commit
git push origin master
git checkout staging
git pull origin staging
git merge master
git push origin staging
git push heroku-staging staging:master
# come back to master for more development
git checkout master
