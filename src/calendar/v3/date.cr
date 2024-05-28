require "msgpack"
require "json"

require "../../resource"

struct Google::Calendar::V3
  struct Date
    include Resource

    @[JSON::Field(converter: ::Google::Calendar::V3::Date::DateConverter)]
    @[MessagePack::Field(converter: ::Google::Calendar::V3::Date::DateConverter)]
    getter date : Time

    def to_time
      date
    end

    def <=>(other : Date)
      date <=> other.date
    end

    def <=>(other : Timestamp)
      date <=> other.date_time
    end

    module DateConverter
      extend self

      FORMAT = Time::Format::ISO_8601_DATE

      def from_json(json : JSON::PullParser)
        FORMAT.parse(json.read_string)
      end

      def from_msgpack(msgpack : MessagePack::Unpacker)
        FORMAT.parse(msgpack.read_string)
      end

      def to_json(value : Time, json : JSON::Builder)
        json.string FORMAT.format(value)
      end

      def to_msgpack(value : Time, msgpack : MessagePack::Packer)
        msgpack.write FORMAT.format(value)
      end
    end
  end
end
