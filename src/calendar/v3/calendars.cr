require "../v3"

require "./calendar"

struct Google::Calendar::V3
  struct Calendars < API
    def list(token : String)
      http_get("/calendars", token: token, as: CalendarList)
    end

    def get(id : String, token : String)
      id = URI.encode_path_segment(id)
      http_get("/calendars/#{id}", token: token, as: Calendar)
    end

    def http_get(path : String, token : String, as type = JSON::Any)
      client.get("/calendar/v3#{path}", token) do |response|
        if response.success?
          type.from_json response.body_io
        else
          raise response.body_io.gets_to_end
        end
      end
    end
  end

  def calendars
    Calendars.new(client)
  end
end
