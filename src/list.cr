require "./resource"

module Google
  struct List(T)
    include Resource
    include Enumerable(T)

    field kind : String
    field etag : String?
    field items : Array(T)
    field next_page_token : String?

    def each(&)
      items.each do |item|
        yield item
      end
    end
  end
end
