require "json"

require "./event"

struct Google::Calendar::V3
  struct EventsListResponse
    include Resource
    include Enumerable(Event)

    field kind : String
    field etag : String
    field summary : String
    field updated : Time
    field time_zone : String
    field access_role : String
    field default_reminders : Array(JSON::Any) { [] of JSON::Any }
    field next_sync_token : String?
    field next_page_token : String?
    field items : Array(Event)

    delegate each, sort_by, to: items
  end
end
