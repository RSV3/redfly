require('coffee-script');
require('longjohn');

require('./config');

require('./lib/server/server');
console.info('App starting in ' + process.env.APP_ENV + ' environment');
