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
      # @[MessagePack::Field(ignore: true)]
      # getter json_unmapped : Hash(String, JSON::Any)
      # @[JSON::Field(ignore: true)]
      # getter msgpack_unmapped : Hash(String, MessagePack::Type)
    end

    macro field(var, key = nil, &block)
      @[JSON::Field(key: {{key ? key : var.var.camelcase(lower: true).stringify}})]
      @[MessagePack::Field(key: {{key ? key : var.var.camelcase(lower: true).stringify}})]
      getter {{var}} {{block}}
    end

    macro field?(var, key = nil, &block)
      @[JSON::Field(key: {{key ? key : var.var.camelcase(lower: true).stringify}})]
      @[MessagePack::Field(key: {{key ? key : var.var.camelcase(lower: true).stringify}})]
      getter? {{var}} {{block}}
    end
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
