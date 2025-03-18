require "http"

require "./api"
require "./resource"
require "./client"
require "./error"

module Google
  @[Experimental("The Gmail API is vestigial. Use with caution. APIs may change")]
  module Gmail
  end

  struct Gmail::V1 < API
    def users(user_id : String = "me")
      Users.new client, user_id
    end

    struct Users < API
      def initialize(client, @user_id : String)
        super client
      end

      def threads
        Threads.new client, @user_id
      end

      struct Threads < API
        def initialize(client, @user_id : String)
          super client
        end

        def list(
          token : String,
          *,
          max_results : UInt32? = nil,
          page_token : String? = nil,
          q query : String? = nil,
          label_ids : Array(String)? = nil,
          include_spam_trash : Bool? = nil,
        )
          params = URI::Params.new
          params.add "maxResults", max_results.to_s if max_results
          params.add "pageToken", page_token if page_token
          params.add "q", query if query
          label_ids.try &.each do |label_id|
            params.add "labelIds", label_id
          end
          params.add "includeSpamTrash", include_spam_trash.to_s unless include_spam_trash.nil?

          client.get "/gmail/v1/users/#{@user_id}/threads?#{params}", token do |response|
            if response.success?
              ThreadList.from_json response.body_io
            else
              raise Error.new(response.body_io.gets_to_end)
            end
          end
        end

        def get(
          id : String,
          token : String,
          *,
          format : Format? = nil,
        )
          client.get "/gmail/v1/users/#{@user_id}/threads/#{id}", token do |response|
            if response.success?
              Thread.from_json response.body_io
            else
              raise Error.new(response.body_io.gets_to_end)
            end
          end
        end

        enum Format
          Full
          Metadata
          Minimal
        end
      end
    end

    struct ThreadList
      include Resource
      field threads : Array(ThreadListItem)
      field next_page_token : String?
      field result_size_estimate : Int64
    end

    abstract struct ThreadBase
      include Resource

      field id : String
      field history_id : String
    end

    struct ThreadListItem < ThreadBase
      field snippet : String
    end

    struct Thread < ThreadBase
      field messages : Array(Message)
    end

    struct Message
      include Resource

      field id : String
      field thread_id : String
      field label_ids : Array(String)
      field snippet : String
      field history_id : String
      field internal_date : Time, converter: ::Google::Gmail::V1::TimestampConverter
      field payload : MessagePart
      field size_estimate : Int64
      field raw : String?
    end

    struct MessagePart
      include Resource

      field part_id : String
      field mime_type : String
      field filename : String?
      field headers : Array(Header) { [] of Header }
      field body : Body
      field parts : Array(MessagePart)?

      struct Body
        include Resource

        field attachment_id : String?
        field size : Int64
        field data : String?
      end
    end

    struct Header
      include Resource

      field name : String
      field value : String
    end

    module TimestampConverter
      extend self

      def from_json(json : JSON::PullParser)
        Time.unix_ms json.read_string.to_i64
      end
    end
  end

  class Client
    def gmail
      Gmail::V1.new self
    end
  end
end
