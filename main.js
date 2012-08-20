require('coffee-script');
require('longjohn');

require('./config');

console.info('App starting in ' + process.env.APP_ENV + ' environment');
require('./lib/server').listen(process.env.PORT || 5000);

// require('derby').run(__dirname + '/lib/server', process.env.PORT || 5000, {numWorkers: 1, requires: ['coffee-script']});