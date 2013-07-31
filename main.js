// profiler plugins:
// should not have both of these at once
var profile_config = {
//	NODETIME_ACCOUNTKEY: '9ed3b83d70427d402822795e80426b7ec5343e2f'	
	STRONG_AGENT_ID: '7f9fd8ac-056b-467b-94a1-12e2babdead9'
};

if (profile_config.NODETIME_ACCOUNT_KEY) {
	console.log('profiling with nodetime ' + profile_config.NODETIME_ACCOUNT_KEY);
   	require('nodetime').profile({accountKey: profile_config.NODETIME_ACCOUNT_KEY});
} else if (profile_config.STRONG_AGENT_ID) {
	console.log('profiling with strong-agent ' + profile_config.STRONG_AGENT_ID);
   	require('strong-agent').profile(
		    profile_config.STRONG_AGENT_ID,
		    ['redfly-staging', 'Heroku'],
			{ blockThreshold: 1234 } // optional options
	);
}

require('phrenetic/main');
