require "../../resource"
require "./conference_solution_key"

struct Google::Calendar::V3
  struct ConferenceData
    include Resource
    field create_request : CreateRequest

    struct CreateRequest
      include Resource

      field request_id : String
      field conference_solution_key : ConferenceSolutionKey
      field status : Status

      struct Status
        include Resource

        field status_code : String
      end
    end
  end
end
