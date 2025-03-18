require "http/client"
require "uri"
require "oauth2"
require "db/pool"

require "./http"

module Google
  class Client
    getter client_id : String
    getter client_secret : String
    getter redirect_uri : URI
    @pool : DB::Pool(HTTPClient)
    @default_headers : HTTP::Headers

    private DEFAULT_HEADERS = HTTP::Headers{
      "Accept"       => "application/json",
      "Content-Type" => "application/json",
    }

    def initialize(
      @client_id,
      @client_secret,
      @redirect_uri,
      @default_headers = DEFAULT_HEADERS.dup
    )
      uri = URI.parse("https://www.googleapis.com")
      @pool = DB::Pool.new(DB::Pool::Options.new(initial_pool_size: 0, max_idle_pool_size: 25)) do
        HTTPClient.new(uri)
      end
    end

    def oauth2_endpoint(
      scope : String,
      access_type : AccessType? = nil,
      prompt : Prompt? = nil
    ) : URI
      oauth = OAuth2::Client.new(
        client_id: client_id,
        client_secret: client_secret,
        host: "accounts.google.com",
        authorize_uri: "/o/oauth2/v2/auth",
        token_uri: "/token",
        redirect_uri: redirect_uri.to_s,
      )

      uri = URI.parse(oauth.get_authorize_uri(scope))
      uri.query_params = uri.query_params.dup.tap do |params|
        params["access_type"] = access_type.to_s
        if prompt
          params["prompt"] = prompt.to_s
        end
      end
      uri
    end

    def get_access_token(code : String)
      oauth = OAuth2::Client.new(
        client_id: client_id,
        client_secret: client_secret,
        host: "oauth2.googleapis.com",
        authorize_uri: "/o/oauth2/v2/auth",
        token_uri: "/token",
        redirect_uri: redirect_uri.to_s,
      )
      oauth.http_client = HTTPClient.new("oauth2.googleapis.com", tls: true)
      oauth.get_access_token_using_authorization_code(code)
    end

    def refresh_access_token(refresh_token : String)
      oauth = OAuth2::Client.new(
        client_id: client_id,
        client_secret: client_secret,
        host: "oauth2.googleapis.com",
        token_uri: "/token",
      )
      oauth.http_client = HTTPClient.new("oauth2.googleapis.com", tls: true)
      oauth.get_access_token_using_refresh_token(refresh_token)
    end

    enum AccessType
      Online
      Offline

      def to_s
        String.build { |io| to_s io }
      end

      def to_s(io)
        member_name.not_nil!.downcase io
      end
    end

    @[Flags]
    enum Prompt
      Consent
      SelectAccount

      def to_s(io) : Nil
        count = 0
        {% for value in @type.constants %} # { |e| e.stringify != "None" && e.stringify != "All" }.map &.stringify }}
          {% if value.stringify != "None" && value.stringify != "All" %}
            if includes?({{value}})
              if (count += 1) > 1
                io << ' '
              end
              io << {{value.stringify.underscore}}
            end
          {% end %}
        {% end %}
      end
    end

    def get(path : String, token : String, headers = HTTP::Headers.new, &)
      headers = headers.dup
      headers["authorization"] = "Bearer #{token}"
      @pool.checkout(&.get(path, headers: DEFAULT_HEADERS.dup.merge!(headers)) { |response| yield response })
    end

    def post(path : String, token : String, body, headers = HTTP::Headers.new, &)
      headers = DEFAULT_HEADERS.dup.merge!(headers)
      headers["authorization"] = "Bearer #{token}"
      @pool.checkout(&.post(path, headers: headers, body: body.to_json) { |response| yield response })
    end
  end
end
