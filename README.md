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
	{"title":"Outlander","imdb_id":"tt3006802"},
	{"title":"The Walking Dead","imdb_id":"tt1520211"},
	{"title":"The Night Manager","imdb_id":"tt1399664"},
	{"title":"24 Legacy","imdb_id":"tt5345490"},
	{"title":"Black Sails","imdb_id":"tt2375692"},
	{"title":"Band of Brothers","imdb_id":"tt0185906"},
	{"title":"Game of Thrones","imdb_id":"tt0944947"}
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
