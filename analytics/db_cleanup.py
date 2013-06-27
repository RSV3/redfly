from pymongo import MongoClient
import pprint
from redfly_config import DEV_DB_URL, STAGING_DB_URL, PROD_DB_URL

"""
  Cleans up the db by deleting and emails that have digit as a prefix
"""

client = MongoClient(DEV_DB_URL)

db = client.heroku_app6379653  # dev
# db = client.heroku_app6375934  # staging
# db = client.heroku_app8065862  # prod
contacts = db.contacts
tags = db.tags
notes = db.notes

results = contacts.aggregate([
  {
    "$match": { "emails": { "$regex": "^\d.*", "$options": "i"}},
  },
  {
    "$unwind": "$emails"
  },
])

"""
    {
      "$group": {
        "_id": "$names",
      },
    }
"""

ids_to_delete = []
for doc in results['result']:
  ids_to_delete.append(doc['_id'])

tags.remove({"contact": {"$in": ids_to_delete}})
notes.remove({"contact": {"$in": ids_to_delete}})
contacts.remove({"_id": {"$in": ids_to_delete}})

results = contacts.aggregate([
  {
    "$match": { "emails": { "$regex": "^\d.*", "$options": "i"}},
  },
  {
    "$unwind": "$emails"
  },
])

pp = pprint.PrettyPrinter(indent=2)
pp.pprint(results)
