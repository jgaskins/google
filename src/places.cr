require "./resource"
require "./api"

module Google
  @[Experimental("The Places API is vestigial. Use with caution. APIs may change")]
  module Places
  end

  struct Places::V1 < API
    def search_text(
      text_query : String,
      *,
      language_code : String? = nil,
      region_code : String? = nil,
      # rank_preference : RankPreference? = nil,
      # included_type : String? = nil,
      # open_now : Bool? = nil
      # min_rating : Number? = nil,
      # page_size : Int? = nil,
      # page_token : String? = nil,
      # price_levels : Array(PriceLevel)? =nil,
      # strict_type_filtering : Bool? = nil
      # location_bias : LocationBias? = nil,
    ) : SearchResponse
      request = SearchRequest.new(
        text_query: text_query,
        language_code: language_code,
        region_code: region_code,
      )
      headers = HTTP::Headers{"Host" => "places.googleapis.com"}

      client.post "/v1/places:searchText",
        headers: headers,
        body: request.to_json,
        as: SearchResponse
    end

    struct SearchRequest
      include Resource

      field text_query : String
      field language_code : String?
      field region_code : String?

      def initialize(
        *,
        @text_query,
        @language_code,
        @region_code,
      )
      end
    end

    struct SearchResponse
      include Resource

      field places : Array(Place)
      # field routing_summaries : Array(RoutingSummary)?
      # field contextual_contents : Array(ContextualContent)?
      field next_page_token : String?
      field search_uri : String?
    end

    struct Place
      include Resource

      field id : String
      field name : String
      # field display_name : LocalizedText
      field types : Array(String)
      field primary_type : String
      # field primary_type_display_name : LocalizedText
      field national_phone_number : String?
      field international_phone_number : String?
      field formatted_address : String?
      field short_formatted_address : String?
    end
  end

  class Client
    def places
      Places::V1.new self
    end
  end
end
