module Google
  class HTTPClient < ::HTTP::Client
    Log = ::Log.for(Google::Client)

    def around_exec(request : ::HTTP::Request)
      start = Time.monotonic
      begin
        response = yield
      ensure
        duration = Time.monotonic - start
        Log.debug &.emit(
          method: request.method,
          resource: request.resource,
          duration_ms: duration.total_milliseconds,
        )
        response
      end
    end
  end
end
