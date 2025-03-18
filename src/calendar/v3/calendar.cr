require "../../resource"

struct Google::Calendar::V3
  struct Calendar
    include Resource
    include JSON::Serializable::Unmapped

    field kind : String
    field etag : String
    field id : String
    field summary : String
    field time_zone : String
    field conference_properties : ConferenceProperties

    struct ConferenceProperties
      include Resource

      field allowed_conference_solution_types : Array(String)
    end
  end
end
