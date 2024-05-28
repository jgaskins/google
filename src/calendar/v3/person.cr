require "../../resource"

struct Google::Calendar::V3
  struct Person
    include Resource

    field id : String?
    field email : String
    field display_name : String?
    field? self : Bool? = nil
  end
end
