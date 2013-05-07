#!/bin/sh

mongodump --host ds039147.mongolab.com:39147 --username heroku_app8065862 --password 6cqi48lldblomdf4uebuhplblj --db heroku_app8065862 --out redfly_dump

mongorestore --host ds043837.mongolab.com:43837 --username heroku_app6379653 --password 2vos1gak0e63rjl5220mluubm6 --db heroku_app6379653 redfly_dump/heroku_app8065862
