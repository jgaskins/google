require "../../resource"
require "../v3"

require "./entrypoint"
require "./conference_solution"
require "./response_status"
require "./conference_data"

struct Google::Calendar::V3
  struct Attendee
    include Resource

    field id : String?
    field email : String?
    field display_name : String?
    field? organizer : Bool?
    field? self : Bool?
    field? resource : Bool?
    field? optional : Bool?
    field response_status : ResponseStatus?
    field comment : String?
    field additional_guests : Int64?
    field hangout_link : URI?
    field conference_data : ConferenceData?
    field entry_points : Array(Entrypoint) { [] of Entrypoint }
    field conference_solution : ConferenceSolution?
    field conference_id : String?
    field signature : String?
    field notes : String?

    def initialize(*, @display_name, @email, @response_status)
    end
  end
end
