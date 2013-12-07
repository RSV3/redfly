from pymongo import MongoClient
import pprint, sys
from redfly_config import DEV_DB_URL, STAGING_DB_URL, PROD_DB_URL

"""
  Cleans up the db by deleting and emails that have digit as a prefix
"""

pp = pprint.PrettyPrinter(indent=2)

client = MongoClient(DEV_DB_URL)
db = client.heroku_app6379653  # dev
# db = client.heroku_app6375934  # staging
# db = client.heroku_app8065862  # prod
contacts = db.contacts
tags = db.tags
notes = db.notes
users = db.users
measurements = db.measurements
fullcontacts = db.fullcontacts
linkedins = db.linkedins
excludes = db.excludes
classifies = db.classifies
mails = db.mails
requests = db.requests

results = users.find({'email': 'lucy@redstar.com'})
if results.count() == 0:
  print "No user to delete"
  sys.exit() 
print "User to delete:"
pp.pprint(results[0])

# find contacts that only this user owns and delete
user_id = results[0]["_id"]
contact_results = contacts.find({'knows': {'$in': [user_id]}}) 

# find contacts that user knows also and remove the user 

ids_to_delete = []
print "Total results:", contact_results.count()
for doc in contact_results:
  if len(doc['knows']) > 1:
    pp.pprint(doc)
    # need to just remove the user from knows list
    old_knows = doc['knows']
    new_knows = []
    for k in old_knows:
      if k != user_id:
        new_knows.append(k)
    contacts.update({'_id': doc['_id']}, {'$set': { 'knows': new_knows }})
  else:
    ids_to_delete.append(doc['_id'])

print "ID's to delete:", len(ids_to_delete)
tags.remove({"contact": {"$in": ids_to_delete}})
notes.remove({"contact": {"$in": ids_to_delete}})
contacts.remove({"_id": {"$in": ids_to_delete}})
measurements.remove({"contact": {"$in": ids_to_delete}})
fullcontacts.remove({"contact": {"$in": ids_to_delete}})
linkedins.remove({"contact": {"$in": ids_to_delete}})
excludes.remove({"user": user_id})
classifies.remove({"user": user_id})
mails.remove({"sender": user_id})
requests.remove({"user": user_id})
users.remove({"_id": user_id})
