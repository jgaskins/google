require "http/client"
require "./src/resource"

include Google

url = ARGV[0]
response = HTTP::Client.get(url)
if response.success?
  define response.body
else
  raise "API discovery request failed: #{url} - #{response.status} - #{response.body}"
end

def define(body)
  puts body
  response = Response.from_json(body)
  pp response
end

module Google::Resource
end

struct Response
  include Resource
  include JSON::Serializable::Unmapped
end
