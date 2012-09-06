require 'html5-manifest'


require 'ember'
App = Ember.Application.create()

views = '../../views/app'


# TODO XXX here on down is demo code!!!!!!!

Contacts.UserView = Ember.View.extend(
	contact: null
	template: require(views + "/user_template")
	classNames: ["user"]
)
contact = Ember.Object.create(
	firstName: "Charles"
	lastName: "Jolley"
	fullName: (->
		[@get("firstName"), @get("lastName")].join " ")
	.property("firstName", "lastName")
)
userView = Contacts.UserView.create()
userView.append()
userView.set "contact", contact

# TODO XXX do I want a loading indicator or not? See if it actually shows up first
# cleanup loading UI
$("h1.loading").remove()
exports.contact = contact
exports.userView = userView
