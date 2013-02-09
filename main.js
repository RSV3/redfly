require('longjohn');
require('coffee-script');

require('./config');

var module = process.argv[2];
require('./lib/' + module);
