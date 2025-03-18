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
    field default_reminders : Array(Reminder)
    field notification_settings : NotificationSettings?
    field conference_properties : ConferenceProperties

    enum AccessRole
      Reader
      Writer
      Owner
      FreeBusyReader
    end

    struct Reminder
      include Resource

      field method : Method
      field minutes : Int64

      enum Method
        Popup
      end
    end

    struct NotificationSettings
      include Resource

      field notifications : Array(NotificationSetting)

      struct NotificationSetting
        include Resource

        field type : Type
        field method : Method

        enum Type
          EventCreation
          EventChange
          EventCancellation
          EventResponse
        end

        enum Method
          Email
        end
      end
    end

    struct ConferenceProperties
      include Resource
      field allowed_conference_solution_types : Array(String)
    end
  end
end
