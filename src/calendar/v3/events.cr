require "../../api"
require "../v3"

struct Google::Calendar::V3
  struct Events < API
    def list(
      calendar : Calendar | CalendarList::Entry,
      token : String,
      *,
      page_size : Int32 | String | Nil = nil,
      time_min : Time? = nil,
      time_max : Time? = nil,
      time_zone : String = "",
      single_events : Bool? = nil,
    )
      list calendar.id, token,
        page_size: page_size,
        time_min: time_min,
        time_max: time_max,
        time_zone: time_zone,
        single_events: single_events
    end

    def list(
      calendar_id : String,
      token : String,
      *,
      page_size : Int32 | String | Nil = nil,
      time_min : Time? = nil,
      time_max : Time? = nil,
      time_zone : String = "",
      single_events : Bool? = nil,
    )
      params = URI::Params{
        "timeMin"      => time_min.try(&.to_rfc3339).to_s,
        "timeMax"      => time_max.try(&.to_rfc3339).to_s,
        "timeZone"     => time_zone,
        "singleEvents" => single_events.to_s,
        "pageSize"     => page_size.to_s,
      }
      params.each do |name, value|
        params.delete name if value.empty?
      end
      get "/calendars/#{URI.encode_path calendar_id}/events?#{params}",
        token: token,
        as: EventsListResponse
    end

    def get(calendar_id : String, id : String, token : String)
      get "/calendars/#{calendar_id}/events/#{id}",
        token: token,
        as: Event
    end

    def get(path : String, token : String, as type : T.class = JSON::Any) forall T
      client.get("/calendar/v3#{path}", token) do |response|
        if response.success?
          T.from_json response.body_io
        else
          raise response.body_io.gets_to_end
        end
      end
    end

    def insert(
      *,
      calendar_id : String = "primary",
      start starts_at : Time,
      end ends_at : Time,
      summary : String? = nil,
      description : String? = nil,
      attachments : Array(URI)? = nil,
      attendees : Array(Attendee)? = nil,
      send_updates : SendUpdates? = nil,
      visibility : Event::Visibility? = nil,
      status : Event::Status? = nil,
      token : String,
    )
      request = EventsInsertRequest.new(
        start: Timestamp.new(date_time: starts_at, time_zone: starts_at.location.to_s),
        end: Timestamp.new(date_time: ends_at, time_zone: ends_at.location.to_s),
        attachments: attachments.try(&.map { |uri| Attachment.new(file_url: uri) }),
        attendees: attendees,
        summary: summary,
        description: description,
        visibility: visibility,
        status: status,
      )
      params = URI::Params.new
      if send_updates
        params["sendUpdates"] = send_updates.to_s
      end
      client.post "/calendar/v3/calendars/#{calendar_id}/events?#{params}", token, request do |response|
        if response.success?
          Event.from_json response.body_io
        else
          raise response.body_io.gets_to_end
        end
      end
    end

    struct EventsInsertRequest
      include Resource

      field start : Timestamp | Date
      field end : Timestamp | Date
      field summary : String?
      field description : String?
      field attendees : Array(Attendee) { [] of Attendee }
      field attachments : Array(Attachment) { [] of Attachment }
      field visibility : Event::Visibility?
      field status : Event::Status?

      def initialize(
        *,
        @start,
        @end,
        @summary = nil,
        @description = nil,
        @attendees = nil,
        @attachments = nil,
        @visibility = nil,
        @status = nil,
      )
      end
    end

    enum SendUpdates
      All
      ExternalOnly
      None

      def to_s
        case self
        in .all?
          "all"
        in .external_only?
          "externalOnly"
        in .none?
          "none"
        end
      end
    end

    struct Attachment
      include Resource

      field file_url : URI

      def initialize(@file_url)
      end
    end
  end

  def events
    Events.new(client)
  end
end
