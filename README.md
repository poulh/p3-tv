# TVTime

A Swiss army knife gem for managing and downloading TV shows

## Create Settings File in home directory named ".tvtime"
```json
{
    "library_path" : "~/Movies",
    "download_path" : "~/Downloads",
    "download_regex" : ["[sS](\\d{1,2})[eE](\\d{1,2})" ],
    "allowed_types" : [ ".mkv", ".avi", ".mp4"],
    "subtitles" : [ ".srt" ],
    "verbose" : true,
    "noop" : true,
    "series" : [
	"Orphan Black"
    ]
}
```

## Installation

    $ gem install tvtime

## Usage

Fetch a series and get all the magnet links:
```ruby
require 'tvtime'

TVTime::catalog_downloads!
TVTime::download_missing!
```


## Contributing

1. Fork it.
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
