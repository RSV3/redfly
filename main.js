require('coffee-script');
require('longjohn');

require('./config');

var module = process.argv[2];
require('./lib/' + module);
