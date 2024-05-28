require "../api"
require "../resource"

module Google
  struct Calendar::V3 < API
  end
end

require "./v3/calendar"
require "./v3/date"
require "./v3/timestamp"
require "./v3/event"
require "./v3/events_list_response"
require "./v3/person"
require "./v3/attendee"
require "./v3/calendar_list"
require "./v3/calendars"
require "./v3/events"
