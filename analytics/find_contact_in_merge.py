from pymongo import MongoClient
import pprint, sys
from redfly_config import DEV_DB_URL, STAGING_DB_URL, PROD_DB_URL

"""
  Cleans up the db by deleting and emails that have digit as a prefix
"""

pp = pprint.PrettyPrinter(indent=2)

#client = MongoClient(DEV_DB_URL)
#db = client.heroku_app6379653  # dev
# db = client.heroku_app6375934  # staging
client = MongoClient(PROD_DB_URL)
db = client.heroku_app8065862  # prod
merges = db.merges

results = merges.find({})

for r in results:
  if len(r['contacts']) > 0:
    for cont in r['contacts']:
      if cont:
        for em in cont['emails']:
          if em == 'myungsoonwoo@comcast.net':
            pp.pprint(r)
