require "../../../resource"

struct Google::Calendar::V3::CalendarList
  struct Entry
    include Resource
    include JSON::Serializable::Unmapped

    field kind : String
    field etag : String
    field id : String
    field summary : String
    field summary_override : String?
    field description : String?
    field time_zone : String
    field color_id : String
    field background_color : String
    field foreground_color : String
    field? selected : Bool = false
    field access_role : AccessRole

    enum AccessRole
      Reader
      Writer
      Owner
      FreeBusyReader
    end
  end
end
