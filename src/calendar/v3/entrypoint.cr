require "uri"

require "../../resource"

struct Google::Calendar::V3
  struct Entrypoint
    include Resource

    field entry_point_type : String?
    field uri : URI?
    field label : String?
    field pin : String?
    field access_code : String?
    field meeting_code : String?
    field passcode : String?
    field password : String?
  end
end
