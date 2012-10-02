#!/bin/sh

heroku config:add HOST='redfly-prod.herokuapp.com' -a redfly-prod
heroku config:add OPTIMIZE=true -a redfly-prod
