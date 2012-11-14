mongoose = require 'mongoose'

mongoose.connect process.env.MONGOLAB_URI
module.exports = mongoose