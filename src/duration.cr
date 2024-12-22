module Google::Duration
  extend self

  def from_json(json : JSON::PullParser)
    string = json.read_string
    duration = 0.seconds

    if (match = string.match(/(\d+(\.\d+)?)s/))
      duration += match[1].to_f.seconds
    end

    if (match = string.match(/(\d+(\.\d+)?)m/))
      duration += match[1].to_f.minutes
    end

    if (match = string.match(/(\d+(\.\d+)?)h/))
      duration += match[1].to_f.hours
    end

    duration
  end
end
