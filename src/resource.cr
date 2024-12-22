require "json"
require "uri/json"
require "uuid/json"
require "msgpack"

module Google
  module Resource
    macro included
      include JSON::Serializable
      include MessagePack::Serializable

      # UNCOMMENT WHEN WE NEED TO DEBUG
      # include JSON::Serializable::Unmapped
      # include MessagePack::Serializable::Unmapped
      # @[JSON::Field(ignore: true)]
      # @[MessagePack::Field(ignore: true)]
      # getter json_unmapped : Hash(String, JSON::Any)
      # @[JSON::Field(ignore: true)]
      # @[MessagePack::Field(ignore: true)]
      # getter msgpack_unmapped : Hash(String, MessagePack::Type)
    end

    macro define(name, *fields)
      struct {{name}}
        include ::Google::Resource

        {% for field in fields %}
          field {{field}}
        {% end %}

        def initialize(
          *,
          {% for field in fields %}
            @{{field.var}}{% unless field.value.is_a? Nop %} = {{field.value}}{% end %},
          {% end %}
        )
        end

        {{yield}}
      end
    end

    private macro define_field(*suffixes)
      {% for suffix in suffixes %}
        macro field{{suffix.id}}(var, key = nil, **options, &block)
          @[JSON::Field(key: \{{key ? key : var.var.camelcase(lower: true).stringify}}\{% for k, v in options %}, \{{k}}: \{{v}}\{% end %})]
          @[MessagePack::Field(key: \{{key ? key : var.var.camelcase(lower: true).stringify}}\{% for k, v in options %}, \{{k}}: \{{v}}\{% end %})]
          getter{{suffix.id}} \{{var}} \{{block}}
        end
      {% end %}
    end

    define_field "", "!", "?"
  end
end

class URI
  def self.new(msgpack : MessagePack::Unpacker)
    parse(msgpack.read_string)
  end

  def to_msgpack(msgpack : MessagePack::Packer)
    msgpack.write to_s
  end
end
