require "../../../resource"

struct Google::Calendar::V3::CalendarList
  struct CalendarListResponse
    include Enumerable(Entry)
    include Resource

    field kind : String
    field etag : String
    field next_page_token : String?
    field next_sync_token : String?
    field items : Array(Entry)

    def each(&)
      items.each { |item| yield item }
    end

    def sort_by(&)
      items.sort_by { |item| yield item }
    end
  end
end
