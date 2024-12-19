# google

Crystal implementations of various Google API clients.

Currently supported APIs:

- Auth (limited)
- Calendar (getting there)
- Cloud Storage
- Drive (limited)
- People (self-identification only)

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
require "google/people"
```

API docs are forthcoming.

## Contributing

1. Fork it (<https://github.com/jgaskins/google/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Jamie Gaskins](https://github.com/jgaskins) - creator and maintainer