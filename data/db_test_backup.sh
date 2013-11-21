#!/bin/sh
# mongodb://heroku_app6375910:uaqkc8grn41ns5k2c2dngdo94k@ds033018.mongolab.com:33018/heroku_app6375910
mongodump --host ds033018.mongolab.com:33018 --username heroku_app6375910 --password uaqkc8grn41ns5k2c2dngdo94k --db heroku_app6375910 --out redfly_test_dump_20130710
