require('coffee-script');

// require('derby').run(__dirname + '/lib/server', 3000, {numWorkers: 1, requires: ['coffee-script']});
require('./lib/server').listen(3000);
