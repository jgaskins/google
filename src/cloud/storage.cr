require "digest/sha256"
require "jwt"

require "../api"
require "../resource"
require "../http"
require "../service_account"
require "../list"
require "../error"

module Google
  class Cloud::Storage
    private DEFAULT_HEADERS = HTTP::Headers{
      "Accept"       => "application/json",
      "Content-Type" => "application/json",
    }

    @pool : DB::Pool(HTTPClient)

    getter credentials : ServiceAccount::Key

    def initialize(@credentials, @storage_host = "storage.googleapis.com")
      uri = URI.parse("https://#{storage_host}")
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

    def presigned_url(
      bucket : String,
      key : String,
      method : String = "GET",
      expires_in : Time::Span = 1.hour,
      content_type : String? = nil,       # For PUT/POST, e.g., "application/octet-stream"
      content_md5_base64 : String? = nil, # For PUT/POST, Base64 encoded MD5
      headers : HTTP::Headers = HTTP::Headers.new,
      payload_handling : String = "UNSIGNED-PAYLOAD", # or hex-encoded SHA256 hash if signing payload
    )
      # 1. Request Details
      service_account_email = @credentials.client_email
      rsa_private_key = OpenSSL::PKey.read(@credentials.private_key)
      unless rsa_private_key.is_a?(OpenSSL::PKey::RSA)
        raise Error.new("Credentials do not contain a valid RSA private key.")
      end

      algorithm = "GOOG4-RSA-SHA256"
      current_time_utc = Time.utc
      request_timestamp = current_time_utc.to_s("%Y%m%dT%H%M%SZ")
      date_stamp = current_time_utc.to_s("%Y%m%d")
      credential_scope = "#{date_stamp}/auto/storage/goog4_request"

      # 2. Canonical URI & Host
      # Ensure the key does not start with a slash if you prepend one.
      # GCS object keys usually don't start with a slash in their canonical representation.
      encoded_canonical_path = "/#{bucket}/#{URI.encode_path(key.lchop('/'))}"

      # 3. Canonical Headers & Signed Headers
      headers_to_sign = Hash(String, String).new
      headers_to_sign["host"] = @storage_host

      if content_type
        headers_to_sign["content-type"] = content_type.strip
      end
      if content_md5_base64
        headers_to_sign["content-md5"] = content_md5_base64.strip
      end

      headers.each do |key, values|
        values.each do |value|
          # Normalize: lowercase, strip whitespace
          headers_to_sign[key.downcase.strip] = value.strip
        end
      end

      sorted_header_names = headers_to_sign.keys.sort
      canonical_headers_string = sorted_header_names.map do |h_name|
        "#{h_name}:#{headers_to_sign[h_name]}"
      end.join('\n') + '\n' # Must end with a newline

      signed_headers_string = sorted_header_names.join(';')

      # 4. Canonical Query String (for elements *other* than X-Goog-*)
      # For simple GET/PUT, this is often empty. If you had other GCS query params like 'generation'
      # they would be built and sorted here.
      canonical_query_params = Hash(String, String){
        "X-Goog-Algorithm"     => algorithm,
        "X-Goog-Credential"    => "#{service_account_email}/#{credential_scope}",
        "X-Goog-Date"          => request_timestamp,
        "X-Goog-Expires"       => expires_in.total_seconds.to_i64.to_s,
        "X-Goog-SignedHeaders" => signed_headers_string,
      }

      sorted_canonical_query_string = canonical_query_params.keys.sort.map do |k|
        "#{URI.encode_www_form(k)}=#{URI.encode_www_form(canonical_query_params[k])}"
      end.join('&')

      # 5. Hashed Payload
      hashed_payload = if method == "GET" || method == "DELETE" || method == "HEAD"
                         Digest::SHA256.hexdigest("") # Typically empty payload for these
                       else
                         payload_handling # "UNSIGNED-PAYLOAD" or a precomputed hash
                       end

      # 6. Canonical Request
      canonical_request_parts = [
        method.upcase,
        encoded_canonical_path,
        sorted_canonical_query_string,
        canonical_headers_string, # Already ends with \n
        signed_headers_string,
        hashed_payload,
      ]
      canonical_request = canonical_request_parts.join('\n')

      # 7. String to Sign
      hashed_canonical_request = Digest::SHA256.hexdigest(canonical_request)

      string_to_sign_parts = [
        algorithm,
        request_timestamp,
        credential_scope,
        hashed_canonical_request,
      ]
      string_to_sign = string_to_sign_parts.join('\n')

      # 8. Sign
      signature_bytes = rsa_private_key.sign(Digest::SHA256.new, string_to_sign.to_slice)
      hex_signature = signature_bytes.hexstring.downcase

      # 9. Assemble Final URL Query Parameters
      final_query_params = Hash(String, String).new
      # Copy over any initially defined canonical query params
      canonical_query_params.each { |k, v| final_query_params[k] = v }

      final_query_params["X-Goog-Algorithm"] = algorithm
      final_query_params["X-Goog-Credential"] = "#{service_account_email}/#{credential_scope}"
      final_query_params["X-Goog-Date"] = request_timestamp
      final_query_params["X-Goog-Expires"] = expires_in.total_seconds.to_i64.to_s
      final_query_params["X-Goog-SignedHeaders"] = signed_headers_string
      final_query_params["X-Goog-Signature"] = hex_signature

      params = URI::Params.new
      final_query_params.keys.sort.each do |key|
        params.add key, final_query_params[key]
      end

      URI.parse("https://#{@storage_host}#{encoded_canonical_path}?#{params}")
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
        raise Error.new(response.body) unless response.success?

        token = OAuth2::AccessToken::Bearer.from_json(response.body)
        if expires_in = token.expires_in
          @token_expires_at = expires_in.seconds.from_now
        end
        @token = token
      else
        token
      end
    end

    def get(path : String, headers = HTTP::Headers.new, &)
      @pool.checkout(&.get(path, headers: headers) { |response| yield response })
    end

    def post(path : String, body, headers = HTTP::Headers.new, &)
      @pool.checkout(&.post(path, headers: headers, body: body) { |response| yield response })
    end

    def delete(path : String, headers = HTTP::Headers.new, &)
      @pool.checkout(&.delete(path, headers: headers) { |response| yield response })
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
            raise Error.new(response.body_io.gets_to_end)
          end
        end
      end

      def http_get(path : String, &)
        client.get("/storage/v1/#{path}") do |response|
          if response.success?
            yield response.body_io
          else
            raise Error.new(response.body_io.gets_to_end)
          end
        end
      end

      def post(path : String, body : IO, &)
        client.post "/storage/v1/#{path}", body: body do |response|
          if response.success?
            yield response.body_io
          else
            raise Error.new(response.body_io.gets_to_end)
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

      def get_data(bucket : String, object : String, &)
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
          response_body.gets_to_end
        end
      end

      def delete(bucket : String, object : String)
        client.delete "/storage/v1/b/#{bucket}/o/#{object}" do |response|
          puts response.body_io.gets_to_end
          response.success?
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
        show_deleted : Bool? = nil,
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
        show_deleted : Bool? = nil,
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

    class Error < Google::Error
    end
  end
end
