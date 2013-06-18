icalendar = require 'icalendar'
fs = require 'fs'

# read file
#
fs.readFile 'invite.ics', 'utf-8', (err, data) ->
  if err
    throw err

  cal = icalendar.parse_calendar(data)
  for ev in cal.events()
    ###
    [ { type: 'CAL-ADDRESS',
        name: 'ATTENDEE',
        value: 'mailto:kwan@redstar.com',
        parameters: 
         { CUTYPE: 'INDIVIDUAL',
           ROLE: 'REQ-PARTICIPANT',
           PARTSTAT: 'NEEDS-ACTION',
           RSVP: 'TRUE',
           CN: 'Kwan Lee',
           'X-NUM-GUESTS': '0' } },
      { type: 'CAL-ADDRESS',
        name: 'ATTENDEE',
        value: 'mailto:arosenfeld.mba2009.hbs@gmail.com',
        parameters: 
         { CUTYPE: 'INDIVIDUAL',
           ROLE: 'REQ-PARTICIPANT',
           PARTSTAT: 'ACCEPTED',
           RSVP: 'TRUE',
           CN: 'Alex Rosenfeld',
           'X-NUM-GUESTS': '0' } },
      { type: 'CAL-ADDRESS',
        name: 'ATTENDEE',
        value: 'mailto:whaas@redstar.com',
        parameters: 
         { CUTYPE: 'INDIVIDUAL',
           ROLE: 'REQ-PARTICIPANT',
           PARTSTAT: 'NEEDS-ACTION',
           RSVP: 'TRUE',
           CN: 'whaas@redstar.com',
           'X-NUM-GUESTS': '0' } },
      { type: 'CAL-ADDRESS',
        name: 'ATTENDEE',
        value: 'mailto:ewisch@redstar.com',
        parameters: 
         { CUTYPE: 'INDIVIDUAL',
           ROLE: 'REQ-PARTICIPANT',
           PARTSTAT: 'NEEDS-ACTION',
           RSVP: 'TRUE',
           CN: 'ewisch@redstar.com',
           'X-NUM-GUESTS': '0' } },
      { type: 'CAL-ADDRESS',
        name: 'ATTENDEE',
        value: 'mailto:adam@redstar.com',
        parameters: 
         { CUTYPE: 'INDIVIDUAL',
           ROLE: 'REQ-PARTICIPANT',
           PARTSTAT: 'NEEDS-ACTION',
           RSVP: 'TRUE',
           CN: 'Adam Weisman',
           'X-NUM-GUESTS': '0' } } ]    
    ###
    for participant in ev.properties['ATTENDEE']
      console.log participant.value
    for organizer in ev.properties['ORGANIZER']
      console.log organizer.value
    console.log 'Description: ' + ev.properties['DESCRIPTION'][0].value
    console.log 'Summary: ' + ev.properties['SUMMARY'][0].value

