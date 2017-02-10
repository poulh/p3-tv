# TVTime

A Swiss army knife gem for managing and downloading TV shows

## Create Settings File in home directory named ".tvtime"
```json
{
    "library_path" : "~/Movies",
    "create_tvtime_dir" : true,
    "download_path" : "~/Downloads",
    "delete_duplicate_downloads" : false,
    "overwrite_duplicates" : true,
    "allowed_types" : [ ".mkv", ".avi", ".mp4"],
    "subtitles" : [ ".srt" ],
    "verbose" : true,
    "noop" : false,
    "series" : [
	"Orphan Black",
	"Fargo",
	"The Man in the High Castle",
	"Shameless",
	"Game of Thrones",
	"Master of None",
	"Outlander",
	"Homeland",
	"The Americans",
	"The Walking Dead"
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
