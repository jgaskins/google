require "../../resource"
require "./conference_solution_key"

struct Google::Calendar::V3
  struct ConferenceSolution
    include Resource

    field key : ConferenceSolutionKey
    field name : String
    field icon_uri : URI
  end
end
