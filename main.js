if (process.env.NODETIME_ACCOUNT_KEY)
   	require('nodetime').profile({accountKey: process.env.NODETIME_ACCOUNT_KEY});

if (process.env.STRONG_AGENT_ID)
   	require('strong-agent').profile(
		    process.env.STRONG_AGENT_ID,
		    [APPLICATION_NAME,'Heroku'],
			{} // optional options
	);

require('phrenetic/main');
