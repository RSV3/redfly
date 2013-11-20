from pymongo import MongoClient
import pprint, sys
from redfly_config import DEV_DB_URL, STAGING_DB_URL, PROD_DB_URL, PROJECT11_STAGING_URL

pp = pprint.PrettyPrinter(indent=2)

client = MongoClient(PROJECT11_STAGING_URL)
db = client.heroku_app6379653  # dev

admin = db.admin
