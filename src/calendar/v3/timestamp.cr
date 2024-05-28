require "../../resource"

struct Google::Calendar::V3
  struct Timestamp
    include Resource

    field date_time : Time
    field time_zone : String

    def initialize(@date_time, @time_zone)
    end

    @@location_cache = Hash(String, Time::Location).new do |cache, name|
      if match = name.match /GMT([\-\+]\d{2}):(\d{2})/
        hour = match[1].to_i
        minute = match[2].to_i
        cache[name] = Time::Location.fixed(
          name: name,
          offset: (hour.hours + minute.minutes).total_seconds.to_i32,
        )
      else
        cache[name] = Time::Location.load(name)
      end
    end

    def to_time
      date_time.in(@@location_cache[@time_zone])
    end

    def <=>(other : Timestamp)
      date_time <=> other.date_time
    end

    def <=>(other : Date)
      date_time <=> other.date
    end
  end
end
