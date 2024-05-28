require "../../resource"

struct Google::Calendar::V3
  enum ResponseStatus
    NeedsAction
    Declined
    Tentative
    Accepted

    def to_json(json : JSON::Builder)
      json.string case self
      in .needs_action?
        "needsAction"
      in .declined?
        "declined"
      in .tentative?
        "tentative"
      in .accepted?
        "accepted"
      end
    end
  end
end
