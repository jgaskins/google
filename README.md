# google

Crystal implementations of various Google API clients.

Currently supported APIs:

- Auth (limited)
- Calendar (getting there)
- Cloud Storage/GCS
- Drive (limited)
- GenerativeAI/Gemini
- Gmail
- Maps (vestigial)
- People (self-identification only)
- Places
- Tasks

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     google:
       github: jgaskins/google
   ```

2. Run `shards install`

## Usage

```crystal
require "google"
```

Load the specific Google API you need to use:

```crystal
require "google/auth"
require "google/calendar"
require "google/cloud/storage"
require "google/drive"
require "google/gemini"
require "google/maps"
require "google/people"
require "google/tasks"
```

### Using the GenerativeAI API (Gemini)

```crystal
require "google/gemini"

client = Google::GenerativeAI::Client.new(gemini_api_key)

gemini = client.model(
  "models/gemini-2.0-flash-exp",
  system_instruction: [<<-PROMPT],
    You are a helpful assistant.
    PROMPT
  temperature: 0.4,
)

puts gemini.generate(<<-PROMPT)
  Write a limerick about the Crystal programming language.
  PROMPT
```

## Contributing

1. Fork it (<https://github.com/jgaskins/google/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Jamie Gaskins](https://github.com/jgaskins) - creator and maintainer
