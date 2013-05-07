#!/bin/sh

mongodump --host ds043847.mongolab.com:43847 --username heroku_app6375934 --password oc78rcclpfcs9iu3i8prldlki3 --db heroku_app6375934 --out redfly_dump

mongorestore --host ds043837.mongolab.com:43837 --username heroku_app6379653 --password 2vos1gak0e63rjl5220mluubm6 --db heroku_app6379653 redfly_dump/heroku_app6375934
