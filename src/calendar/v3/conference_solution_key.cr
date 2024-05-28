require "../../resource"

struct Google::Calendar::V3
  struct ConferenceSolutionKey
    include Resource

    field type : String
  end
end
