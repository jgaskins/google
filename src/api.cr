require "./client"

module Google
  abstract struct API
    getter client : Client

    def initialize(@client)
    end

    macro discover(url)
      {{run "../discover", url}}
      {% debug %}
    end
  end
end
