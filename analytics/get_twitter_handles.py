from pymongo import MongoClient
import json
from redfly_config import PROD_DB_URL

# prod db
client = MongoClient(PROD_DB_URL)

db = client.heroku_app8065862
collection = db.fullcontacts

tweet_handles = set([]) 

for item in collection.find({'socialProfiles.typeName': 'Twitter'}):
  for socprof in item['socialProfiles']:
    if socprof['typeId'] == 'twitter':
      if 'username' in socprof:
        tweet_handles.add(socprof['username'])
      else:
        tweet_handles.add(socprof['url'])

for handle in tweet_handles:
  print handle

