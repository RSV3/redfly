from pymongo import MongoClient
import json

client = MongoClient()

client = MongoClient('mongodb://heroku_app6379653:2vos1gak0e63rjl5220mluubm6@ds043837.mongolab.com:43837/heroku_app6379653')

db = client.heroku_app6379653
collection = db.fullcontacts

element = collection.find_one({'socialProfiles.typeName': 'Linkedin'})
print element

print "FullContact information"
print "Total FullContact contacts:", collection.find({}).count()
print "Total FullContact with LinkedIn:", collection.find({'socialProfiles.typeName': 'Linkedin'}).count()

# full contact with linkedin profiles, there are many duplicates
for item in collection.find({'socialProfiles.typeName': 'Linkedin'}):
  print item['contactInfo']['fullName'] if 'contactInfo' in item else None
  for socprof in item['socialProfiles']:
    if socprof['typeId'] == 'linkedin':
      print socprof['url']


collection = db.linkedins
print "LinkedIn information"
print "Total linkedin connections:", collection.find({}).count()
print "Total linkedin connection w/o contact:", collection.find({'contact': {'$exists': False}}).count()

# check linkedin collections
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

print "Total contacts:"
collection = db.contacts

print collection.find().count()
