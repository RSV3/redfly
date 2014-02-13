require('coffee-script');
require('longjohn');

var projectRoot = require('path').dirname(module.parent.filename);

require('./lib/server/config')(projectRoot);

var module = process.argv[2];
// Special case because the server module takes an arguement.
if (module == 'server')
	require('./lib/server')(projectRoot);
else try {
	require(projectRoot + '/lib/' + module);
} catch (err) {
	console.dir(err);
	require('./lib/' + module);
}
