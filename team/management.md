development commands:
mongo ds043837.mongolab.com:43837/heroku_app6379653 -u heroku_app6379653 -p 2vos1gak0e63rjl5220mluubm6
redis-cli -h koi.redistogo.com -p 9609 -a d8fafc860dfba6c9d50b6dbabc90653b

test commands:
mongo ds037097.mongolab.com:37097/heroku_app6375910 -u heroku_app6375910 -p osf31ssqike03ju6i6852jd0v2

staging commands:
mongo ds043847.mongolab.com:43847/heroku_app6375934 -u heroku_app6375934 -p oc78rcclpfcs9iu3i8prldlki3

prod commands:
mongo ds039147.mongolab.com:39147/heroku_app8065862 -u heroku_app8065862 -p 6cqi48lldblomdf4uebuhplblj

dumping prod db to dev:
mongodump --host ds039147.mongolab.com:39147 --username heroku_app8065862 --password 6cqi48lldblomdf4uebuhplblj --db heroku_app8065862 --out redfly_dump
- drop all the collections in heroku
mongorestore --host ds043837.mongolab.com:43837 --username heroku_app6379653 --password 2vos1gak0e63rjl5220mluubm6 --db heroku_app6379653 redfly_dump/heroku_app8065862


Tutorials
===============

- http://wekeroad.com/2012/02/25/testing-your-model-with-mocha-mongo-and-nodejs
- http://dailyjs.com/2011/12/08/mocha/
- http://net.tutsplus.com/tutorials/javascript-ajax/better-coffeescript-testing-with-mocha/
- http://brianstoner.com/blog/testing-in-nodejs-with-mocha/
- http://robdodson.me/blog/2012/05/28/mocking-requests-with-mocha-chai-and-sinon/
- http://www.adaltas.com/blog/2012/02/19/nodejs-test-mocha-should-travis/
- http://blog.james-carr.org/2012/01/16/blog-rolling-with-mongodb-node-js-and-coffeescript/
- http://www.coffeescriptlove.com/2012/02/testing-coffeescript-with-mocha.html
- http://www.scoop.it/t/nodejs-code
- http://tympanus.net/codrops/2012/10/11/real-time-geolocation-service-with-node-js/


Add-Ons added
====================
All: Mongolab, RedisToGo, Sendgrid
Non-dev: Email Hook
Prodlike: Scheduler

- No ZerigoDNS, added domains directly I think

Scraping
====================
- http://node.io/

A/B Testing
====================
- https://github.com/maccman/abba
