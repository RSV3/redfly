if process.env.NODETIME_ACCOUNT_KEY then require('nodetime').profile accountKey: process.env.NODETIME_ACCOUNT_KEY

require('phrenetic/main');
