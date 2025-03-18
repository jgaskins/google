require "uri"
require "../../resource"
require "./timestamp"
require "./date"
require "./event/status"

struct Google::Calendar::V3
  # https://developers.google.com/calendar/api/v3/reference/events
  struct Event
    include Resource

    field kind : String
    field etag : String
    field id : String
    field status : Status
    field html_link : URI
    field created : Time { updated }
    field updated : Time
    field summary : String?
    field description : String?
    field location : String?
    field color_id : String?
    field creator : Person?
    field organizer : Person?
    field start : Timestamp | Date
    field end : Timestamp | Date
    field? end_time_unspecified : Bool?
    field recurrence : Array(String) { [] of String }
    field recurring_event_id : String?
    field original_start_time : Timestamp | Date | Nil
    field transparency : String?
    field visibility : Visibility = :default
    field ical_uid : String, key: "iCalUID"
    field sequence : Int64?
    field attendees : Array(Attendee) { [] of Attendee }
    field attendees_omitted : Bool?
    field extended_properties : ExtendedProperties?
    field reminders : Reminders?
    field event_type : EventType?

    def initialize(
      *,
      @id,
      @etag,
      @status,
      @html_link,
      @start,
      @end,
      @ical_uid,
      @kind = "calendar#event",
      @updated = Time.utc,
      @created = Time.utc,
      @summary = nil,
      @description = nil,
      @location = nil,
      @color_id = nil,
      @creator = nil,
      @organizer = nil,
      @end_time_unspecified = nil,
      @recurrence = nil,
      @recurring_event_id = nil,
      @original_start_time = nil,
      @transparency = nil,
      @visibility = :default,
      @sequence = nil,
      @attendees = nil,
      @attendees_omitted = nil,
      @extended_properties = nil,
      @reminders = nil,
      @event_type = nil
    )
    end

    def all_day?
      start.is_a? Date
    end

    def overlaps?(range : Range(Time, Time))
      range_start = case start = @start
                    in Timestamp
                      start.date_time
                    in Date
                      time = start.date
                      Time.local(
                        year: time.year,
                        month: time.month,
                        day: time.day,
                        location: range.begin.location,
                      )
                    end
      range_end = case finish = @end
                  in Timestamp
                    finish.date_time
                  in Date
                    time = finish.date
                    Time.local(
                      year: time.year,
                      month: time.month,
                      day: time.day,
                      location: range.end.location,
                    )
                  end

      range_start < range.begin < range_end ||
        range_start < range.end < range_end ||
        range.begin < range_start < range.end ||
        range.begin < range_end < range.end
    end

    enum Visibility
      Default
      Public
      Private
      Confidential
    end

    enum EventType
      Default
      OutOfOffice
      FocusTime
      WorkingLocation
      FromGmail
    end

    struct Reminders
      include Resource

      field? use_default : Bool?
      field overrides : Array(Override) { [] of Override }

      struct Override
        include Resource

        field method : String?
        field minutes : Int64?
      end
    end

    struct ExtendedProperties
      include Resource

      field private : Hash(String, String) { {} of String => String }
      field shared : Hash(String, String) { {} of String => String }
    end
  end
end
