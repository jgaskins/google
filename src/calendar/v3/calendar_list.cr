require "json"

require "../../api"

struct Google::Calendar::V3
  struct CalendarList < API
    def list(
      token : String,
      user : String = "me",
      *,
      next_sync_token : String? = nil,
      next_page_token : String? = nil,
      max_results : Int? = nil,
      show_deleted : Bool? = nil,
      show_hidden : Bool? = nil
    )
      params = URI::Params.new
      params["maxResults"] = max_results.to_s unless max_results.nil?
      params["nextSyncToken"] = next_sync_token unless next_sync_token.nil?
      params["nextPageToken"] = next_page_token unless next_page_token.nil?
      params["showHidden"] = show_hidden.to_s unless show_hidden.nil?
      params["showDeleted"] = show_deleted.to_s unless show_deleted.nil?

      http_get "/users/#{user}/calendarList?#{params}",
        token: token,
        as: CalendarListResponse
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

  def calendar_list
    CalendarList.new(client)
  end
end

require "./calendar_list/entry"
require "./calendar_list/response"
