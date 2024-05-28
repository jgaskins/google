require "jwt"

require "../api"
require "../resource"
require "../http"
require "../service_account"
require "../list"

module Google
  class Cloud::Storage
    private DEFAULT_HEADERS = HTTP::Headers{
      "Accept"       => "application/json",
      "Content-Type" => "application/json",
    }

    @pool : DB::Pool(HTTPClient)

    getter credentials : ServiceAccount::Key

    def initialize(@credentials)
      uri = URI.parse("https://storage.googleapis.com")
      @pool = DB::Pool.new(DB::Pool::Options.new(initial_pool_size: 0, max_idle_pool_size: 25)) do
        http = HTTPClient.new(uri)
        http.before_request do |request|
          request.headers["authorization"] = "Bearer #{token.access_token}"
          request.headers["Accept"] ||= "application/json"
          request.headers["Content-Type"] ||= "application/json"
        end
        http
      end
    end

    def get(path : String, headers = HTTP::Headers.new)
      @pool.checkout(&.get(path, headers: headers) { |response| yield response })
    end

    def post(path : String, body, headers = HTTP::Headers.new)
      @pool.checkout(&.post(path, headers: headers, body: body) { |response| yield response })
    end

    @token : OAuth2::AccessToken::Bearer?
    @token_expires_at : Time?

    protected def token
      token = @token
      if token.nil? || token_expired?
        headers = HTTP::Headers{
          "Content-Type" => "application/x-www-form-urlencoded",
          "Host"         => @credentials.token_uri.host.not_nil!,
        }
        body = HTTP::Params{
          "grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer",
          "assertion"  => jwt,
        }.to_s

        response = HTTP::Client.post(@credentials.token_uri, headers, body)
        # pp response = @pool.checkout &.post @credentials.token_uri.path, headers, body
        raise response.body unless response.success?

        token = OAuth2::AccessToken::Bearer.from_json(response.body)
        if expires_in = token.expires_in
          @token_expires_at = expires_in.seconds.from_now
        end
        @token = token
      else
        token
      end
    end

    private def token_expired?
      token = @token
      return true if token.nil?

      if expires_at = @token_expires_at
        expires_at < Time.utc
      else
        false
      end
    end

    private def jwt(exp : Time = 1.hour.from_now)
      scope = "https://www.googleapis.com/auth/devstorage.read_write"
      payload = {
        iss:   credentials.client_email,
        scope: scope,
        aud:   credentials.token_uri,
        exp:   exp.to_unix,
        iat:   Time.utc.to_unix,
      }

      JWT.encode payload, credentials.private_key, :rs256
    end

    private abstract struct API
      getter client : Storage

      def initialize(@client)
      end

      def http_get(path : String, as type = JSON::Any)
        client.get("/storage/v1/#{path}") do |response|
          if response.success?
            type.from_json response.body_io
          else
            raise response.body_io.gets_to_end
          end
        end
      end

      def http_get(path : String)
        client.get("/storage/v1/#{path}") do |response|
          if response.success?
            yield response.body_io
          else
            raise response.body_io.gets_to_end
          end
        end
      end

      def post(path : String, body : IO)
        client.post "/storage/v1/#{path}", body: body do |response|
          if response.success?
            yield response.body_io
          else
            raise response.body_io.gets_to_end
          end
        end
      end
    end

    struct Buckets < API
      def list
        params = URI::Params{
          "project" => client.credentials.project_id,
        }
        http_get "b?#{params}", as: JSON::Any
      end

      def get(id : String)
        id = URI.encode_path_segment(id)
        http_get "b/#{id}", as: JSON::Any
      end
    end

    struct Objects < API
      def list(bucket : String)
        list = http_get "b/#{bucket}/o", as: List(Object)
        # if (next_page_token = list.next_page_token)
        #   list.api = self
        #   list.token = token
        #   list.max_results = max_results
        #   list.task_list = task_list
        #   list.completed = completed
        # end
        list
      end

      def get(bucket : String, object : String)
        http_get "b/#{bucket}/o/#{object}", as: Object
      end

      def get_data(bucket : String, object : String)
        http_get "b/#{bucket}/o/#{object}?alt=media" do |io|
          yield io
        end
      end

      def insert(bucket : String, name : String, from stream : IO)
        params = URI::Params{
          "name"       => name,
          "uploadType" => "media",
        }
        reader, writer = IO.pipe
        spawn do
          IO.copy stream, writer
        ensure
          writer.close
        end
        post "b/#{bucket}/o?#{params}", reader do |response_body|
          pp response_body.gets_to_end
        end
      end
    end

    struct Tasks < API
      private alias TimeRange = Range(Time?, Time?) | Range(Time, Nil) | Range(Nil, Time)

      def list(
        task_list : TaskList,
        token : String,
        *,
        max_results : Int32? = nil,
        page_token : String? = nil,
        completed : TimeRange? = nil,
        show_completed : Bool? = nil,
        show_hidden : Bool? = nil,
        show_deleted : Bool? = nil
      )
        list task_list.id, token,
          max_results: max_results,
          page_token: page_token,
          completed: completed,
          show_completed: show_completed,
          show_hidden: show_hidden,
          show_deleted: show_deleted
      end

      def list(
        task_list : String,
        token : String,
        *,
        max_results : Int32? = nil,
        page_token : String? = nil,
        completed : TimeRange? = nil,
        show_completed : Bool? = nil,
        show_hidden : Bool? = nil,
        show_deleted : Bool? = nil
      )
        params = URI::Params.new
        params["maxResults"] = max_results.to_s if max_results
        params["pageToken"] = page_token if page_token
        params["showCompleted"] = show_completed.to_s unless show_completed.nil?
        params["showHidden"] = show_hidden.to_s unless show_hidden.nil?
        params["showDeleted"] = show_deleted.to_s unless show_deleted.nil?

        if completed
          if min = completed.begin
            params["completedMin"] = min.to_rfc3339(fraction_digits: 9)
          end
          if max = completed.end
            params["completedMax"] = max.to_rfc3339(fraction_digits: 9)
          end
        end

        list = http_get "lists/#{task_list}/tasks?#{params}", token: token, as: List(Task)
        if (next_page_token = list.next_page_token)
          list.api = self
          list.token = token
          list.max_results = max_results
          list.task_list = task_list
          list.completed = completed
        end
        list
      end

      struct List(T)
        include Resource
        include Enumerable(T)

        field kind : String
        field etag : String
        field items : Array(T)
        field next_page_token : String?
        @[JSON::Field(ignore: true)]
        protected property api : Tasks?
        @[JSON::Field(ignore: true)]
        protected property task_list : String?
        @[JSON::Field(ignore: true)]
        protected property token : String?
        @[JSON::Field(ignore: true)]
        protected property max_results : Int32?
        @[JSON::Field(ignore: true)]
        protected property completed : TimeRange?

        def to_a
          lists = [] of TaskList
          each { |list| lists << list }
          lists
        end

        def each(page_count : Int32? = nil, &block : T ->) : Nil
          items.each do |item|
            yield item
          end

          if page_count && page_count > 1 && (api = self.api) && (token = self.token) && (task_list = self.task_list) && (next_page_token = self.next_page_token)
            api
              .list(
                task_list: task_list,
                token: token,
                max_results: max_results,
                page_token: next_page_token,
                completed: completed,
              )
              .each(page_count: page_count - 1, &block)
          end
        end
      end
    end

    def buckets
      Buckets.new self
    end

    def objects
      Objects.new self
    end

    struct Object
      include Resource
      # include JSON::Serializable::Unmapped

      field kind : String
      field id : String
      field etag : String?
      field self_link : URI
      field media_link : URI
      field name : String
      field bucket : String
      field generation : String
      field metageneration : String
      field content_type : String
      field storage_class : String # TODO: Make this an enum
      field size : String
      field md5_hash : String
      field crc32c : String
      field time_created : Time
      field updated : Time
      field time_storage_class_updated : Time
    end
  end
end
