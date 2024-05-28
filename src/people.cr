require "http"

require "./resource"

module Google
  struct People::V1
    getter client : Client

    def initialize(@client)
    end

    def me(token : String)
      get "me", token
    end

    def get(resource_name : String, token : String)
      params = URI::Params{
        "personFields" => %w[
          emailAddresses
          names
          metadata
          photos
        ].join(','),
      }
      uri = URI.parse("https://people.googleapis.com/v1/people/#{resource_name}?#{params}")
      headers = HTTP::Headers{
        "host"          => "people.googleapis.com",
        "authorization" => "Bearer #{token}",
      }
      HTTP::Client.get(uri, headers: headers) do |response|
        if response.success?
          # JSON.parse response.body_io
          GetPersonResponse.from_json response.body_io
        else
          raise response.body_io.gets_to_end
        end
      end
    end

    struct GetPersonResponse
      include Resource

      field resource_name : String
      field etag : String
      field metadata : Metadata
      field names : Array(Name) { [] of Name }
      field photos : Array(Photo) { [] of Photo }
      field email_addresses : Array(EmailAddress) { [] of EmailAddress }

      struct EmailAddress
        include Resource

        field metadata : FieldMetadata
        field value : String
      end

      struct Photo
        include Resource

        field metadata : FieldMetadata
        field url : URI
        field? default : Bool? = nil
      end

      struct Name
        include Resource

        field metadata : FieldMetadata
        field display_name : String
        field given_name : String
        field family_name : String
        field display_name_last_first : String
        field unstructured_name : String
      end

      struct FieldMetadata
        include Resource

        field? primary : Bool?
        field? verified : Bool?
        field source : Source
        field? source_primary : Bool?

        struct Source
          include Resource

          field type : String
          field id : String
        end
      end

      struct Metadata
        include Resource

        field sources : Array(Source)
        field object_type : String

        abstract struct Source
          include Resource

          use_json_discriminator "type", {
            PROFILE:        Profile,
            DOMAIN_PROFILE: DomainProfile,
          }

          field type : String
          field id : String
          field etag : String
          field update_time : Time
        end

        struct Profile < Source
          field profile_metadata : Hash(String, JSON::Any)
        end

        struct DomainProfile < Source
        end
      end
    end
  end

  class Client
    def people
      People::V1.new(self)
    end
  end
end
