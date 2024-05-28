require "./calendar/v3"

module Google
  class Client
    def calendar
      Calendar::V3.new(self)
    end
  end
end
