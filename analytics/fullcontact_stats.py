from pymongo import MongoClient
import json

client = MongoClient()

client = MongoClient('mongodb://heroku_app6379653:2vos1gak0e63rjl5220mluubm6@ds043837.mongolab.com:43837/heroku_app6379653')

db = client.heroku_app6379653
collection = db.fullcontacts

element = collection.find_one({'socialProfiles.typeName': 'Linkedin'})
print element

print collection.find({}).count()
print collection.find({'socialProfiles.typeName': 'Linkedin'}).count()

# full contact with linkedin profiles, there are many duplicates
for item in collection.find({'socialProfiles.typeName': 'Linkedin'}):
  print item['contactInfo']['fullName'] if 'contactInfo' in item else None
  for socprof in item['socialProfiles']:
    if socprof['typeId'] == 'linkedin':
      print socprof['url']


collection = db.linkedins
print collection.find({}).count()
print collection.find({'contact': {'$exists': False}}).count()

# check linkedin collections
print "LinkedIn information"
for item in collection.find({'contact': {'$exists': False}}):
  if 'linkedinId' in item:
    print item['linkedinId']
  else:
    print "linkedin id does not exist for %ss" % item['headline']

#for item in collection.find({'contact': {'$exists': True}}):
#  if 'linkedinId' in item:
#    print item['linkedinId']
#  else:
#    print "linkedin id does not exist for %ss" % item['headline']
print collection.find({'linkedinId': {'$exists': False}}).count()

